CREATE TABLE IF NOT EXISTS "admin_tasks" (
    "task_id" UUID PRIMARY KEY DEFAULT UUIDV7(),
    "task_type" TEXT NOT NULL CHECK (
        "task_type" IN ('manual_pdf_review', 'missing_draw_result')
    ),
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "draw_date" DATE NOT NULL,
    "denomination" INT NOT NULL CHECK (
        "denomination" IN (100, 200, 750, 1500, 25000, 40000)
    ),
    "source_url" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending' CHECK (
        "status" IN ('pending', 'in_progress', 'completed', 'dismissed')
    ),
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS "uq_admin_tasks_pdf_source"
    ON "admin_tasks" ("source_url")
    WHERE "task_type" = 'manual_pdf_review';

CREATE UNIQUE INDEX IF NOT EXISTS "uq_admin_tasks_missing_draw"
    ON "admin_tasks" ("draw_date", "denomination")
    WHERE "task_type" = 'missing_draw_result';
