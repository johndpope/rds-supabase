-- JWT Utility Functions for RDS

-- Ensure pgcrypto extension is installed first
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create JWT schema
CREATE SCHEMA IF NOT EXISTS jwt;

-- URL Encode function
CREATE OR REPLACE FUNCTION jwt.url_encode(data BYTEA)
RETURNS TEXT LANGUAGE SQL AS $$
SELECT translate(encode(data, 'base64'), E'+/=\n', '-_');
$$;

-- URL Decode function
CREATE OR REPLACE FUNCTION jwt.url_decode(data TEXT)
RETURNS BYTEA LANGUAGE SQL AS $$
WITH 
    t AS (SELECT translate(data, '-_', '+/')),
    rem AS (SELECT length((SELECT * FROM t)) % 4)
SELECT decode(
    (SELECT * FROM t) ||
    CASE WHEN (SELECT * FROM rem) > 0
         THEN repeat('=', (4 - (SELECT * FROM rem)))
         ELSE '' END,
    'base64'
);
$$;

-- Algorithm Sign function (modified to use pgcrypto instead of public.hmac)
CREATE OR REPLACE FUNCTION jwt.algorithm_sign(signables TEXT, secret TEXT, algorithm TEXT)
RETURNS TEXT LANGUAGE SQL AS $$
WITH 
    alg AS (
        SELECT CASE 
            WHEN algorithm = 'HS256' THEN 'sha256'
            WHEN algorithm = 'HS384' THEN 'sha384'
            WHEN algorithm = 'HS512' THEN 'sha512'
            ELSE '' END
    )
SELECT jwt.url_encode(
    digest(
        signables, 
        (SELECT * FROM alg)
    )
);
$$;

-- JWT Sign function
CREATE OR REPLACE FUNCTION jwt.sign(payload JSON, secret TEXT, algorithm TEXT DEFAULT 'HS256')
RETURNS TEXT LANGUAGE SQL AS $$
WITH
    header AS (
        SELECT jwt.url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8'))
    ),
    payload_encoded AS (
        SELECT jwt.url_encode(convert_to(payload::TEXT, 'utf8'))
    ),
    signables AS (
        SELECT (SELECT * FROM header) || '.' || (SELECT * FROM payload_encoded)
    )
SELECT 
    (SELECT * FROM signables) 
    || '.' || 
    jwt.algorithm_sign(
        (SELECT * FROM signables), 
        secret, 
        algorithm
    );
$$;

-- JWT Verify function
CREATE OR REPLACE FUNCTION jwt.verify(token TEXT, secret TEXT, algorithm TEXT DEFAULT 'HS256')
RETURNS TABLE(header JSON, payload JSON, valid BOOLEAN) 
LANGUAGE SQL AS $$
SELECT
    convert_from(jwt.url_decode(r[1]), 'utf8')::JSON AS header,
    convert_from(jwt.url_decode(r[2]), 'utf8')::JSON AS payload,
    r[3] = jwt.algorithm_sign(r[1] || '.' || r[2], secret, algorithm) AS valid
FROM regexp_split_to_array(token, '\.') r;
$$;

-- Optional: Create a schema for sensitive data if needed
CREATE SCHEMA IF NOT EXISTS sensitive;

-- Example of a sensitive data table (if required)
CREATE TABLE IF NOT EXISTS sensitive.token_secret (
    shared_secret TEXT NOT NULL
);