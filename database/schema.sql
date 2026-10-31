CREATE TABLE IF NOT EXISTS users (
 id BIGSERIAL PRIMARY KEY, name VARCHAR(120) NOT NULL, email VARCHAR(255) UNIQUE NOT NULL,
 password_hash TEXT NOT NULL, role VARCHAR(20) NOT NULL CHECK(role IN ('farmer','consumer')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS products (
 id BIGSERIAL PRIMARY KEY, farmer_id BIGINT NOT NULL REFERENCES users(id),
 name VARCHAR(160) NOT NULL, category VARCHAR(80) NOT NULL, description TEXT,
 unit VARCHAR(30) NOT NULL, available_quantity NUMERIC(14,2) NOT NULL CHECK(available_quantity>=0),
 price_per_unit NUMERIC(12,2) NOT NULL CHECK(price_per_unit>=0), location VARCHAR(180),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS orders (
 id BIGSERIAL PRIMARY KEY, product_id BIGINT NOT NULL REFERENCES products(id),
 consumer_id BIGINT NOT NULL REFERENCES users(id), farmer_id BIGINT NOT NULL REFERENCES users(id),
 quantity NUMERIC(14,2) NOT NULL CHECK(quantity>0), unit_price NUMERIC(12,2) NOT NULL,
 fulfillment VARCHAR(20) NOT NULL CHECK(fulfillment IN ('pickup','delivery')),
 status VARCHAR(30) NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','accepted','rejected','completed','cancelled')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS messages (
 id BIGSERIAL PRIMARY KEY, sender_id BIGINT NOT NULL REFERENCES users(id),
 room VARCHAR(100) NOT NULL, message TEXT NOT NULL CHECK(length(message)<=2000),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_products_farmer ON products(farmer_id);
CREATE INDEX IF NOT EXISTS idx_orders_farmer ON orders(farmer_id);
CREATE INDEX IF NOT EXISTS idx_messages_room_time ON messages(room,created_at);