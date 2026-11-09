CREATE TABLE IF NOT EXISTS "admin_audit" (
    "event_id" UUID PRIMARY KEY DEFAULT UUIDV7(),
    "occurred_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actor_admin_id" UUID REFERENCES "admins"("id") ON DELETE SET NULL,
    "action" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "subject_id" TEXT,
    "description" TEXT NOT NULL,
    "http_method" VARCHAR(10) NOT NULL,
    "route" TEXT NOT NULL,
    "status_code" SMALLINT NOT NULL CHECK ("status_code" BETWEEN 100 AND 599),
    "duration_ms" DOUBLE PRECISION NOT NULL CHECK ("duration_ms" >= 0),
    "client_ip" INET,
    "user_agent" TEXT,
    "request_id" UUID NOT NULL UNIQUE
);

CREATE INDEX IF NOT EXISTS "idx_admin_audit_occurred_at"
    ON "admin_audit" ("occurred_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_admin_audit_actor_time"
    ON "admin_audit" ("actor_admin_id", "occurred_at" DESC);
