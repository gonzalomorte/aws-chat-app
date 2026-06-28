CREATE TABLE IF NOT EXISTS chat_message (
  id        BIGSERIAL PRIMARY KEY,
  username  VARCHAR(100) NOT NULL,
  message   TEXT NOT NULL,
  timestamp TIMESTAMP NOT NULL
);