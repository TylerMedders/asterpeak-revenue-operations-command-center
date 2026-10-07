-- AsterPeak Software — Revenue Operations Command Center
-- Raw CRM schema generated from the locked Data Dictionary.
-- Business-required fields are intentionally NOT enforced as NOT NULL in raw tables,
-- because the project dataset contains realistic data-quality issues for audit analysis.

CREATE SCHEMA IF NOT EXISTS raw;
SET search_path TO raw;

DROP TABLE IF EXISTS "opportunity_forecast_snapshots" CASCADE;
DROP TABLE IF EXISTS "opportunity_close_date_history" CASCADE;
DROP TABLE IF EXISTS "deal_approvals" CASCADE;
DROP TABLE IF EXISTS "opportunity_products" CASCADE;
DROP TABLE IF EXISTS "products" CASCADE;
DROP TABLE IF EXISTS "activities" CASCADE;
DROP TABLE IF EXISTS "opportunity_stage_history" CASCADE;
DROP TABLE IF EXISTS "opportunities" CASCADE;
DROP TABLE IF EXISTS "contacts" CASCADE;
DROP TABLE IF EXISTS "accounts" CASCADE;
DROP TABLE IF EXISTS "leads" CASCADE;
DROP TABLE IF EXISTS "users" CASCADE;
DROP TABLE IF EXISTS "states" CASCADE;
DROP TABLE IF EXISTS "territories" CASCADE;

CREATE TABLE "territories" (
    "territory_id" INTEGER PRIMARY KEY,
    "territory_name" VARCHAR(20)
);

CREATE TABLE "states" (
    "state_code" CHAR(2) PRIMARY KEY,
    "state_name" VARCHAR(30),
    "territory_id" INTEGER
);

CREATE TABLE "users" (
    "user_id" VARCHAR(10) PRIMARY KEY,
    "first_name" VARCHAR(50),
    "last_name" VARCHAR(50),
    "email" VARCHAR(100),
    "job_title" VARCHAR(75),
    "team" VARCHAR(50),
    "segment" VARCHAR(20),
    "territory_id" INTEGER,
    "manager_id" VARCHAR(10),
    "annual_quota" NUMERIC(12,2),
    "hire_date" DATE,
    "is_active" BOOLEAN
);

CREATE TABLE "leads" (
    "lead_id" VARCHAR(10) PRIMARY KEY,
    "first_name" VARCHAR(50),
    "last_name" VARCHAR(50),
    "email" VARCHAR(100),
    "company_name" VARCHAR(100),
    "job_title" VARCHAR(75),
    "employee_count" INTEGER,
    "state_code" CHAR(2),
    "segment" VARCHAR(20),
    "lead_source" VARCHAR(50),
    "lead_score" INTEGER,
    "lifecycle_stage" VARCHAR(40),
    "lead_status" VARCHAR(25),
    "owner_id" VARCHAR(10),
    "created_at" TIMESTAMP,
    "mql_at" TIMESTAMP,
    "owner_assigned_at" TIMESTAMP,
    "first_response_at" TIMESTAMP,
    "sql_at" TIMESTAMP,
    "disqualification_reason" VARCHAR(75),
    "is_converted" BOOLEAN,
    "converted_at" TIMESTAMP,
    "converted_account_id" VARCHAR(10),
    "converted_contact_id" VARCHAR(10),
    "converted_opportunity_id" VARCHAR(10)
);

CREATE TABLE "accounts" (
    "account_id" VARCHAR(10) PRIMARY KEY,
    "account_name" VARCHAR(100),
    "website" VARCHAR(150),
    "industry" VARCHAR(50),
    "employee_count" INTEGER,
    "estimated_annual_revenue" NUMERIC(14,2),
    "state_code" CHAR(2),
    "segment" VARCHAR(20),
    "territory_id" INTEGER,
    "owner_id" VARCHAR(10),
    "account_status" VARCHAR(25),
    "created_at" TIMESTAMP
);

CREATE TABLE "contacts" (
    "contact_id" VARCHAR(10) PRIMARY KEY,
    "account_id" VARCHAR(10),
    "first_name" VARCHAR(50),
    "last_name" VARCHAR(50),
    "email" VARCHAR(100),
    "job_title" VARCHAR(75),
    "phone" VARCHAR(25),
    "contact_role" VARCHAR(40),
    "lead_source" VARCHAR(50),
    "original_lead_id" VARCHAR(10),
    "owner_id" VARCHAR(10),
    "created_at" TIMESTAMP,
    "is_active" BOOLEAN
);

CREATE TABLE "opportunities" (
    "opportunity_id" VARCHAR(10) PRIMARY KEY,
    "opportunity_name" VARCHAR(150),
    "account_id" VARCHAR(10),
    "primary_contact_id" VARCHAR(10),
    "owner_id" VARCHAR(10),
    "opportunity_type" VARCHAR(25),
    "lead_source" VARCHAR(50),
    "created_at" TIMESTAMP,
    "stage" VARCHAR(40),
    "stage_probability" INTEGER,
    "forecast_category" VARCHAR(20),
    "expected_close_date" DATE,
    "actual_close_date" DATE,
    "next_step" VARCHAR(200),
    "last_activity_date" DATE,
    "closed_lost_reason" VARCHAR(75),
    "list_arr" NUMERIC(12,2),
    "discount_pct" NUMERIC(5,2),
    "net_arr" NUMERIC(12,2),
    "contract_term_months" INTEGER,
    "subscription_tcv" NUMERIC(14,2),
    "implementation_fee_list" NUMERIC(12,2),
    "implementation_discount_pct" NUMERIC(5,2),
    "implementation_fee_booked" NUMERIC(12,2),
    "payment_terms" VARCHAR(20),
    "billing_schedule" VARCHAR(30),
    "custom_pricing_flag" BOOLEAN,
    "nonstandard_contract_terms" BOOLEAN,
    "deal_desk_required" BOOLEAN
);

CREATE TABLE "opportunity_stage_history" (
    "stage_history_id" VARCHAR(12) PRIMARY KEY,
    "opportunity_id" VARCHAR(10),
    "stage" VARCHAR(40),
    "entered_at" TIMESTAMP,
    "exited_at" TIMESTAMP,
    "changed_by_user_id" VARCHAR(10)
);

CREATE TABLE "activities" (
    "activity_id" VARCHAR(12) PRIMARY KEY,
    "activity_type" VARCHAR(25),
    "activity_date" TIMESTAMP,
    "user_id" VARCHAR(10),
    "lead_id" VARCHAR(10),
    "contact_id" VARCHAR(10),
    "account_id" VARCHAR(10),
    "opportunity_id" VARCHAR(10),
    "subject" VARCHAR(150),
    "outcome" VARCHAR(50),
    "completed_flag" BOOLEAN
);

CREATE TABLE "products" (
    "product_id" VARCHAR(10) PRIMARY KEY,
    "product_name" VARCHAR(75),
    "product_category" VARCHAR(30),
    "revenue_type" VARCHAR(20),
    "standard_unit_price" NUMERIC(12,2),
    "included_users" INTEGER,
    "is_active" BOOLEAN
);

CREATE TABLE "opportunity_products" (
    "opportunity_product_id" VARCHAR(12) PRIMARY KEY,
    "opportunity_id" VARCHAR(10),
    "product_id" VARCHAR(10),
    "quantity" INTEGER,
    "standard_unit_price" NUMERIC(12,2),
    "line_list_value" NUMERIC(12,2)
);

CREATE TABLE "deal_approvals" (
    "approval_id" VARCHAR(12) PRIMARY KEY,
    "opportunity_id" VARCHAR(10),
    "approval_type" VARCHAR(40),
    "requested_by_user_id" VARCHAR(10),
    "approver_user_id" VARCHAR(10),
    "requested_at" TIMESTAMP,
    "decision_at" TIMESTAMP,
    "approval_status" VARCHAR(20),
    "requested_discount_pct" NUMERIC(5,2),
    "exception_details" VARCHAR(250),
    "business_justification" VARCHAR(300),
    "approver_comments" VARCHAR(300)
);

CREATE TABLE "opportunity_close_date_history" (
    "close_date_history_id" VARCHAR(12) PRIMARY KEY,
    "opportunity_id" VARCHAR(10),
    "old_close_date" DATE,
    "new_close_date" DATE,
    "changed_at" TIMESTAMP,
    "changed_by_user_id" VARCHAR(10)
);

CREATE TABLE "opportunity_forecast_snapshots" (
    "forecast_snapshot_id" VARCHAR(14) PRIMARY KEY,
    "snapshot_date" DATE,
    "opportunity_id" VARCHAR(10),
    "owner_id" VARCHAR(10),
    "stage" VARCHAR(40),
    "forecast_category" VARCHAR(20),
    "stage_probability" INTEGER,
    "expected_close_date" DATE,
    "net_arr" NUMERIC(12,2),
    "last_activity_date" DATE
);

ALTER TABLE "states"
    ADD CONSTRAINT "fk_states_territory_id_1" FOREIGN KEY ("territory_id")
    REFERENCES "territories" ("territory_id");

ALTER TABLE "users"
    ADD CONSTRAINT "fk_users_territory_id_2" FOREIGN KEY ("territory_id")
    REFERENCES "territories" ("territory_id");

ALTER TABLE "accounts"
    ADD CONSTRAINT "fk_accounts_territory_id_3" FOREIGN KEY ("territory_id")
    REFERENCES "territories" ("territory_id");

ALTER TABLE "leads"
    ADD CONSTRAINT "fk_leads_state_code_4" FOREIGN KEY ("state_code")
    REFERENCES "states" ("state_code");

ALTER TABLE "accounts"
    ADD CONSTRAINT "fk_accounts_state_code_5" FOREIGN KEY ("state_code")
    REFERENCES "states" ("state_code");

ALTER TABLE "users"
    ADD CONSTRAINT "fk_users_manager_id_6" FOREIGN KEY ("manager_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "leads"
    ADD CONSTRAINT "fk_leads_owner_id_7" FOREIGN KEY ("owner_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "accounts"
    ADD CONSTRAINT "fk_accounts_owner_id_8" FOREIGN KEY ("owner_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "contacts"
    ADD CONSTRAINT "fk_contacts_owner_id_9" FOREIGN KEY ("owner_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "opportunities"
    ADD CONSTRAINT "fk_opportunities_owner_id_10" FOREIGN KEY ("owner_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "opportunity_stage_history"
    ADD CONSTRAINT "fk_opportunity_stage_history_changed_by_user_id_11" FOREIGN KEY ("changed_by_user_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "activities"
    ADD CONSTRAINT "fk_activities_user_id_12" FOREIGN KEY ("user_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "deal_approvals"
    ADD CONSTRAINT "fk_deal_approvals_requested_by_user_id_13" FOREIGN KEY ("requested_by_user_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "deal_approvals"
    ADD CONSTRAINT "fk_deal_approvals_approver_user_id_14" FOREIGN KEY ("approver_user_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "contacts"
    ADD CONSTRAINT "fk_contacts_account_id_15" FOREIGN KEY ("account_id")
    REFERENCES "accounts" ("account_id");

ALTER TABLE "opportunities"
    ADD CONSTRAINT "fk_opportunities_account_id_16" FOREIGN KEY ("account_id")
    REFERENCES "accounts" ("account_id");

ALTER TABLE "leads"
    ADD CONSTRAINT "fk_leads_converted_account_id_17" FOREIGN KEY ("converted_account_id")
    REFERENCES "accounts" ("account_id");

ALTER TABLE "leads"
    ADD CONSTRAINT "fk_leads_converted_contact_id_18" FOREIGN KEY ("converted_contact_id")
    REFERENCES "contacts" ("contact_id");

ALTER TABLE "leads"
    ADD CONSTRAINT "fk_leads_converted_opportunity_id_19" FOREIGN KEY ("converted_opportunity_id")
    REFERENCES "opportunities" ("opportunity_id");

ALTER TABLE "contacts"
    ADD CONSTRAINT "fk_contacts_original_lead_id_20" FOREIGN KEY ("original_lead_id")
    REFERENCES "leads" ("lead_id");

ALTER TABLE "opportunities"
    ADD CONSTRAINT "fk_opportunities_primary_contact_id_21" FOREIGN KEY ("primary_contact_id")
    REFERENCES "contacts" ("contact_id");

ALTER TABLE "opportunity_stage_history"
    ADD CONSTRAINT "fk_opportunity_stage_history_opportunity_id_22" FOREIGN KEY ("opportunity_id")
    REFERENCES "opportunities" ("opportunity_id");

ALTER TABLE "activities"
    ADD CONSTRAINT "fk_activities_lead_id_23" FOREIGN KEY ("lead_id")
    REFERENCES "leads" ("lead_id");

ALTER TABLE "activities"
    ADD CONSTRAINT "fk_activities_contact_id_24" FOREIGN KEY ("contact_id")
    REFERENCES "contacts" ("contact_id");

ALTER TABLE "activities"
    ADD CONSTRAINT "fk_activities_account_id_25" FOREIGN KEY ("account_id")
    REFERENCES "accounts" ("account_id");

ALTER TABLE "activities"
    ADD CONSTRAINT "fk_activities_opportunity_id_26" FOREIGN KEY ("opportunity_id")
    REFERENCES "opportunities" ("opportunity_id");

ALTER TABLE "opportunity_products"
    ADD CONSTRAINT "fk_opportunity_products_opportunity_id_27" FOREIGN KEY ("opportunity_id")
    REFERENCES "opportunities" ("opportunity_id");

ALTER TABLE "opportunity_products"
    ADD CONSTRAINT "fk_opportunity_products_product_id_28" FOREIGN KEY ("product_id")
    REFERENCES "products" ("product_id");

ALTER TABLE "deal_approvals"
    ADD CONSTRAINT "fk_deal_approvals_opportunity_id_29" FOREIGN KEY ("opportunity_id")
    REFERENCES "opportunities" ("opportunity_id");

ALTER TABLE "opportunity_close_date_history"
    ADD CONSTRAINT "fk_opportunity_close_date_history_opportunity_id_30" FOREIGN KEY ("opportunity_id")
    REFERENCES "opportunities" ("opportunity_id");

ALTER TABLE "opportunity_close_date_history"
    ADD CONSTRAINT "fk_opportunity_close_date_history_changed_by_user_id_31" FOREIGN KEY ("changed_by_user_id")
    REFERENCES "users" ("user_id");

ALTER TABLE "opportunity_forecast_snapshots"
    ADD CONSTRAINT "fk_opportunity_forecast_snapshots_opportunity_id_32" FOREIGN KEY ("opportunity_id")
    REFERENCES "opportunities" ("opportunity_id");

ALTER TABLE "opportunity_forecast_snapshots"
    ADD CONSTRAINT "fk_opportunity_forecast_snapshots_owner_id_33" FOREIGN KEY ("owner_id")
    REFERENCES "users" ("user_id");

CREATE INDEX "idx_leads_owner_id" ON "leads" ("owner_id");
CREATE INDEX "idx_leads_state_code" ON "leads" ("state_code");
CREATE INDEX "idx_leads_converted_account_id" ON "leads" ("converted_account_id");
CREATE INDEX "idx_leads_converted_contact_id" ON "leads" ("converted_contact_id");
CREATE INDEX "idx_leads_converted_opportunity_id" ON "leads" ("converted_opportunity_id");
CREATE INDEX "idx_accounts_owner_id" ON "accounts" ("owner_id");
CREATE INDEX "idx_accounts_state_code" ON "accounts" ("state_code");
CREATE INDEX "idx_accounts_territory_id" ON "accounts" ("territory_id");
CREATE INDEX "idx_contacts_account_id" ON "contacts" ("account_id");
CREATE INDEX "idx_contacts_owner_id" ON "contacts" ("owner_id");
CREATE INDEX "idx_contacts_original_lead_id" ON "contacts" ("original_lead_id");
CREATE INDEX "idx_opportunities_account_id" ON "opportunities" ("account_id");
CREATE INDEX "idx_opportunities_owner_id" ON "opportunities" ("owner_id");
CREATE INDEX "idx_opportunities_primary_contact_id" ON "opportunities" ("primary_contact_id");
CREATE INDEX "idx_opportunities_stage" ON "opportunities" ("stage");
CREATE INDEX "idx_opportunities_expected_close_date" ON "opportunities" ("expected_close_date");
CREATE INDEX "idx_opportunity_stage_history_opportunity_id" ON "opportunity_stage_history" ("opportunity_id");
CREATE INDEX "idx_opportunity_stage_history_entered_at" ON "opportunity_stage_history" ("entered_at");
CREATE INDEX "idx_activities_lead_id" ON "activities" ("lead_id");
CREATE INDEX "idx_activities_account_id" ON "activities" ("account_id");
CREATE INDEX "idx_activities_opportunity_id" ON "activities" ("opportunity_id");
CREATE INDEX "idx_activities_activity_date" ON "activities" ("activity_date");
CREATE INDEX "idx_opportunity_products_opportunity_id" ON "opportunity_products" ("opportunity_id");
CREATE INDEX "idx_opportunity_products_product_id" ON "opportunity_products" ("product_id");
CREATE INDEX "idx_deal_approvals_opportunity_id" ON "deal_approvals" ("opportunity_id");
CREATE INDEX "idx_deal_approvals_approver_user_id" ON "deal_approvals" ("approver_user_id");
CREATE INDEX "idx_opportunity_close_date_history_opportunity_id" ON "opportunity_close_date_history" ("opportunity_id");
CREATE INDEX "idx_opportunity_close_date_history_changed_at" ON "opportunity_close_date_history" ("changed_at");
CREATE INDEX "idx_opportunity_forecast_snapshots_opportunity_id" ON "opportunity_forecast_snapshots" ("opportunity_id");
CREATE INDEX "idx_opportunity_forecast_snapshots_snapshot_date" ON "opportunity_forecast_snapshots" ("snapshot_date");
