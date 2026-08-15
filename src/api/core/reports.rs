use std::{
    collections::HashMap,
    sync::LazyLock,
    time::{Duration, Instant},
};

use reqwest::Method;
use rocket::{Route, serde::json::Json};
use serde::Serialize;
use serde_json::Value;
use tokio::sync::Mutex;

use crate::{api::JsonResult, auth::Headers, error::Error, http_client::make_http_request};

pub fn routes() -> Vec<Route> {
    routes![get_passkey_directory]
}

// Mirrors upstream `GetPasskeyDirectoryQuery`:
// https://github.com/bitwarden/server/blob/main/src/Core/Dirt/Reports/ReportFeatures/GetPasskeyDirectoryQuery.cs
const PASSKEY_DIRECTORY_URL: &str = "https://passkeys-api.2fa.directory/v1/all.json";
// Upstream caches via FusionCache for 24h; we mirror that with a simple in-memory TTL cache.
const CACHE_DURATION: Duration = Duration::from_hours(24);

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct PasskeyDirectoryEntry {
    domain_name: String,
    passwordless: bool,
    mfa: bool,
    instructions: String,
}

type CachedDirectory = (Instant, Vec<PasskeyDirectoryEntry>);

static CACHE: LazyLock<Mutex<Option<CachedDirectory>>> = LazyLock::new(|| Mutex::new(None));

// The client gates its "Passkey Report" UI behind the `inno-passkey-directory-report`
// feature flag (see config() in api/core/mod.rs), and the upstream server route this
// mirrors is `GET /reports/passkey-directory`, gated behind the same flag server-side.
#[get("/reports/passkey-directory")]
async fn get_passkey_directory(_headers: Headers) -> JsonResult {
    let mut cache = CACHE.lock().await;

    if let Some((fetched_at, entries)) = cache.as_ref()
        && fetched_at.elapsed() < CACHE_DURATION
    {
        return Ok(Json(serde_json::to_value(entries)?));
    }

    let entries = fetch_passkey_directory().await?;
    *cache = Some((Instant::now(), entries.clone()));

    Ok(Json(serde_json::to_value(entries)?))
}

// Directory entries look like:
// { "github.com": { "passwordless": "...", "mfa": "...", "documentation": "https://..." }, ... }
// We only care whether the passwordless/mfa keys are present, same as upstream.
async fn fetch_passkey_directory() -> Result<Vec<PasskeyDirectoryEntry>, Error> {
    let res = make_http_request(Method::GET, PASSKEY_DIRECTORY_URL)?.send().await?;
    let directory: HashMap<String, Value> = res.error_for_status()?.json().await?;

    let entries = directory
        .into_iter()
        .filter_map(|(domain_name, service_data)| {
            let passwordless = service_data.get("passwordless").and_then(Value::as_str).is_some();
            let mfa = service_data.get("mfa").and_then(Value::as_str).is_some();

            if !passwordless && !mfa {
                return None;
            }

            let instructions = service_data.get("documentation").and_then(Value::as_str).unwrap_or_default().to_owned();

            Some(PasskeyDirectoryEntry {
                domain_name,
                passwordless,
                mfa,
                instructions,
            })
        })
        .collect();

    Ok(entries)
}
