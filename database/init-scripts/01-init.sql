CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_price ON products(price);

-- Insert sample data
INSERT INTO products (name, description, price, stock) VALUES
('MacBook Pro 16"', 'High-performance laptop with M2 Pro chip', 2499.99, 10),
('iPhone 15 Pro', 'Latest iPhone with titanium design', 999.99, 25),
('AirPods Pro', 'Wireless earbuds with active noise cancellation', 249.99, 50),
('iPad Air', '10.9-inch iPad with M1 chip', 599.99, 30),
('Apple Watch Series 9', 'Advanced smartwatch with health monitoring', 399.99, 20),
('Magic Mouse', 'Wireless mouse with touch surface', 79.99, 100),
('Magic Keyboard', 'Wireless keyboard with numeric keypad', 129.99, 75),
('Studio Display', '27-inch 5K Retina display', 1599.99, 5),
('Mac Studio', 'Compact professional desktop computer', 1999.99, 8),
('HomePod mini', 'Smart speaker with Siri', 99.99, 40);

-- Create a function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at 
    BEFORE UPDATE ON products 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column(); 