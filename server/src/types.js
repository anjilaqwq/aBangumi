// Shared JSDoc typedefs (no runtime code). Kept separate so every module can
// import the same shapes for editor/type hinting.

/**
 * @typedef {object} Config
 * @property {number} port
 * @property {string} clientId
 * @property {string} clientSecret
 * @property {string} publicBaseUrl
 * @property {string} appCallbackUri
 * @property {string} corsOrigin
 * @property {number} stateTtlMs
 * @property {number} ticketTtlMs
 * @property {number} sessionTtlMs
 * @property {number} bodyLimitBytes
 */

/**
 * @typedef {object} Session
 * @property {string} accessToken
 * @property {string} refreshToken
 * @property {number} accessExpiresAt 0 = unknown (no proactive refresh)
 * @property {number} sessionExpiresAt opaque app-session lifetime
 * @property {number} createdAt
 */

/**
 * @typedef {{ status: number, headers: Record<string, string>, body: Buffer }} HttpResponse
 */

export {};
