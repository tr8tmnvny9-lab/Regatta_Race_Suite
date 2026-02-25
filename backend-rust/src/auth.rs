use jsonwebtoken::{decode, decode_header, DecodingKey, Validation, Algorithm};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error};

#[derive(Debug, Deserialize)]
pub struct AppleJwks {
    pub keys: Vec<AppleJwk>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AppleJwk {
    pub kty: String,
    pub kid: String,
    pub use_: Option<String>,
    pub alg: String,
    pub n: String,
    pub e: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AppleClaims {
    pub iss: String,
    pub sub: String,
    pub aud: String,
    pub iat: u64,
    pub exp: u64,
    pub email: Option<String>,
    pub email_verified: Option<UnionStringOrBool>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
pub enum UnionStringOrBool {
    String(String),
    Bool(bool),
}

pub struct AuthEngine {
    keys: RwLock<HashMap<String, DecodingKey>>,
    roles: RwLock<HashMap<String, String>>, // socket_id -> role
}

impl AuthEngine {
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            keys: RwLock::new(HashMap::new()),
            roles: RwLock::new(HashMap::new()),
        })
    }
    
    pub async fn set_role(&self, socket_id: &str, role: &str) {
        let mut roles = self.roles.write().await;
        roles.insert(socket_id.to_string(), role.to_string());
    }

    pub async fn get_role(&self, socket_id: &str) -> Option<String> {
        let roles = self.roles.read().await;
        roles.get(socket_id).cloned()
    }
    
    pub async fn remove_role(&self, socket_id: &str) {
        let mut roles = self.roles.write().await;
        roles.remove(socket_id);
    }

    pub async fn refresh_apple_keys(&self) {
        info!("Fetching latest Apple public keys from appleid.apple.com/auth/keys...");
        match reqwest::get("https://appleid.apple.com/auth/keys").await {
            Ok(res) => {
                if let Ok(jwks) = res.json::<AppleJwks>().await {
                    let mut cache = self.keys.write().await;
                    cache.clear();
                    let count = jwks.keys.len();
                    for jwk in jwks.keys {
                        if let Ok(decoding_key) = DecodingKey::from_rsa_components(&jwk.n, &jwk.e) {
                            cache.insert(jwk.kid.clone(), decoding_key);
                        }
                    }
                    info!("Successfully cached {} Apple cryptographic keys.", count);
                } else {
                    error!("Failed to parse Apple JWKS payload");
                }
            }
            Err(e) => {
                error!("Network failure pulling Apple JWKS: {}", e);
            }
        }
    }

    /// Verifies the token and returns the subject (Apple ID) if successful.
    pub async fn verify_apple_token(&self, token: &str, client_id: &str) -> Option<String> {
        let header = match decode_header(token) {
            Ok(h) => h,
            Err(_) => {
                warn!("Invalid JWT header format");
                return None;
            }
        };

        let kid = match header.kid {
            Some(k) => k,
            None => {
                warn!("JWT is missing 'kid' header field");
                return None;
            }
        };

        let keys = self.keys.read().await;
        let decoding_key = match keys.get(&kid) {
            Some(key) => key,
            None => {
                warn!("Key {} not found in local cache. Token rejected.", kid);
                return None;
            }
        };

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_audience(&[client_id]);
        validation.set_issuer(&["https://appleid.apple.com"]);

        match decode::<AppleClaims>(token, decoding_key, &validation) {
            Ok(token_data) => Some(token_data.claims.sub),
            Err(e) => {
                warn!("Cryptographic validation failed: {}", e);
                None
            }
        }
    }
}
