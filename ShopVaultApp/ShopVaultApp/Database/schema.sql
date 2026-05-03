-- ShopVault Database Schema
-- SQLite with SQLCipher encryption (AES-256)
-- Generated: 2026-02-18

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY NOT NULL,
    biometric_enabled INTEGER NOT NULL DEFAULT 1,
    pin_hash TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Categories lookup table
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#4CAF50',
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, name)
);
CREATE INDEX idx_categories_user_id ON categories(user_id);

-- Income entries (main data)
CREATE TABLE IF NOT EXISTS income_entries (
    id TEXT PRIMARY KEY NOT NULL,
    user_id TEXT NOT NULL,
    amount DECIMAL(12, 2) NOT NULL CHECK(amount > 0),
    source TEXT NOT NULL,
    category_id TEXT NOT NULL,
    date DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT
);
CREATE INDEX idx_income_entries_user_date ON income_entries(user_id, date DESC);
CREATE INDEX idx_income_entries_category ON income_entries(category_id);

-- App settings
CREATE TABLE IF NOT EXISTS app_settings (
    user_id TEXT PRIMARY KEY NOT NULL,
    auto_lock_timeout_seconds INTEGER NOT NULL DEFAULT 300,
    currency TEXT NOT NULL DEFAULT 'USD',
    locale TEXT NOT NULL DEFAULT 'en_US',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Schema versioning (for migrations)
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

-- Insert initial schema version
INSERT OR IGNORE INTO schema_version (version, description) 
VALUES (1, 'Initial schema: users, categories, income_entries, app_settings');
