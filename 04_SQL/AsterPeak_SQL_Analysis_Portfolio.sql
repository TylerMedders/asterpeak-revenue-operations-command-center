-- AsterPeak Software — Revenue Operations Command Center
-- Portfolio SQL Analysis
-- Database: PostgreSQL | Schema: raw
-- Analysis date used for reproducibility: 2026-09-28

-- ============================================================
-- SECTION 1 — ACCOUNT DATA QUALITY AND ROUTING
-- ============================================================

-- 1.1 Account data-quality summary
SELECT
    COUNT(*) AS total_accounts,
    SUM(CASE WHEN employee_count IS NULL THEN 1 ELSE 0 END) AS missing_employee_count,
    SUM(CASE WHEN owner_id IS NULL THEN 1 ELSE 0 END) AS unassigned_owner,
    SUM(CASE WHEN employee_count < 20 OR employee_count >= 2500 THEN 1 ELSE 0 END) AS outside_target_range,
    SUM(CASE WHEN segment IS NULL AND employee_count BETWEEN 20 AND 2499 THEN 1 ELSE 0 END) AS unexpected_missing_segment
FROM raw.accounts;
-- Finding: 325 accounts; 6 missing employee count; 6 unassigned owners; 9 outside target range; 0 unexpected missing segments.

-- 1.2 Territory and ownership audit using state-derived territory
WITH account_routing AS (
    SELECT
        a.account_id,
        a.account_name,
        a.state_code,
        a.segment,
        a.territory_id AS stored_territory_id,
        s.territory_id AS expected_territory_id,
        a.owner_id AS actual_owner_id,
        CASE
            WHEN a.segment = 'SMB' THEN 'SMB'
            WHEN a.segment IN ('Mid-Market', 'Upper Mid-Market') THEN 'MM'
            ELSE NULL
        END AS expected_owner_segment
    FROM raw.accounts a
    LEFT JOIN raw.states s
        ON a.state_code = s.state_code
),
ownership_audit AS (
    SELECT
        ar.*,
        eu.user_id AS expected_owner_id,
        CASE
            WHEN ar.expected_territory_id IS NULL THEN 'Missing State'
            WHEN ar.stored_territory_id IS NULL THEN 'Missing Stored Territory'
            WHEN ar.stored_territory_id <> ar.expected_territory_id THEN 'Wrong Territory'
            ELSE 'Correct'
        END AS territory_status,
        CASE
            WHEN ar.expected_owner_segment IS NULL THEN 'Needs Review'
            WHEN ar.expected_territory_id IS NULL THEN 'Needs Review'
            WHEN ar.actual_owner_id IS NULL THEN 'Unassigned'
            WHEN eu.user_id IS NULL THEN 'Needs Review'
            WHEN ar.actual_owner_id = eu.user_id THEN 'Correct'
            ELSE 'Misassigned'
        END AS owner_status
    FROM account_routing ar
    LEFT JOIN raw.users eu
        ON eu.territory_id = ar.expected_territory_id
       AND eu.segment = ar.expected_owner_segment
       AND eu.job_title LIKE '%Account Executive%'
)
SELECT
    territory_status,
    owner_status,
    COUNT(*) AS account_count
FROM ownership_audit
GROUP BY territory_status, owner_status
ORDER BY account_count DESC;
-- Finding: 10 wrong stored territories, 4 missing stored territories, 4 records missing state needed to validate routing, 9 genuinely misassigned owners, and 6 unassigned owners.

-- ============================================================
-- SECTION 2 — OPPORTUNITY PIPELINE HEALTH AND PERFORMANCE
-- ============================================================

-- 2.1 Stage summary
SELECT
    stage,
    COUNT(*) AS opportunity_count,
    SUM(net_arr) AS total_net_arr
FROM raw.opportunities
GROUP BY stage
ORDER BY total_net_arr DESC;

-- 2.2 Open-pipeline health
WITH pipeline_health AS (
    SELECT
        opportunity_id,
        opportunity_name,
        stage,
        net_arr,
        expected_close_date,
        last_activity_date,
        CASE
            WHEN expected_close_date < DATE '2026-09-28'
             AND (last_activity_date IS NULL OR DATE '2026-09-28' - last_activity_date > 30)
                THEN 'Stale + Overdue'
            WHEN expected_close_date < DATE '2026-09-28'
                THEN 'Overdue'
            WHEN last_activity_date IS NULL OR DATE '2026-09-28' - last_activity_date > 30
                THEN 'Stale'
            ELSE 'Healthy'
        END AS pipeline_health_status
    FROM raw.opportunities
    WHERE stage NOT IN ('Closed Won', 'Closed Lost')
)
SELECT
    pipeline_health_status,
    COUNT(*) AS opportunity_count,
    SUM(net_arr) AS pipeline_arr
FROM pipeline_health
GROUP BY pipeline_health_status
ORDER BY pipeline_arr DESC;
-- Finding: 107 healthy / $3.974M; 24 overdue / $1.003M; 24 stale / $838K; 5 stale+overdue / $209K.

-- 2.3 Closed-lost reasons
SELECT
    closed_lost_reason,
    COUNT(*) AS lost_opportunity_count
FROM raw.opportunities
WHERE stage = 'Closed Lost'
GROUP BY closed_lost_reason
ORDER BY lost_opportunity_count DESC;

-- 2.4 Pricing/budget loss rate by product
WITH pricing_budget_losses AS (
    SELECT
        p.product_name,
        COUNT(DISTINCT o.opportunity_id) AS pricing_budget_losses
    FROM raw.opportunities o
    JOIN raw.opportunity_products op
        ON o.opportunity_id = op.opportunity_id
    JOIN raw.products p
        ON op.product_id = p.product_id
    WHERE o.stage = 'Closed Lost'
      AND o.closed_lost_reason IN ('No budget', 'Pricing')
    GROUP BY p.product_name
),
closed_product_opportunities AS (
    SELECT
        p.product_name,
        COUNT(DISTINCT o.opportunity_id) AS closed_opportunities
    FROM raw.opportunities o
    JOIN raw.opportunity_products op
        ON o.opportunity_id = op.opportunity_id
    JOIN raw.products p
        ON op.product_id = p.product_id
    WHERE o.stage IN ('Closed Won', 'Closed Lost')
    GROUP BY p.product_name
)
SELECT
    c.product_name,
    COALESCE(p.pricing_budget_losses, 0) AS pricing_budget_losses,
    c.closed_opportunities,
    ROUND(100.0 * COALESCE(p.pricing_budget_losses, 0) / c.closed_opportunities, 1) AS pricing_budget_loss_rate_pct
FROM closed_product_opportunities c
LEFT JOIN pricing_budget_losses p
    ON c.product_name = p.product_name
ORDER BY pricing_budget_loss_rate_pct DESC;
-- Finding: Essentials and Essentials Implementation had the highest observed pricing/budget loss rates (~20.7%), but losses were concentrated in the SMB segment.

-- 2.5 Performance by customer segment
SELECT
    a.segment,
    COUNT(*) AS closed_opportunities,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) AS won_opportunities,
    ROUND(100.0 * SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate_pct,
    ROUND(AVG(CASE WHEN o.stage = 'Closed Won' THEN o.net_arr END), 0) AS avg_won_arr
FROM raw.opportunities o
JOIN raw.accounts a
    ON o.account_id = a.account_id
WHERE o.stage IN ('Closed Won', 'Closed Lost')
GROUP BY a.segment
ORDER BY win_rate_pct DESC;
-- Finding: SMB 50.5% / $18.9K avg won ARR; Mid-Market 59.2% / $35.4K; Upper Mid-Market 64.2% / $57.5K.

-- 2.6 Rep performance
SELECT
    CONCAT(u.first_name, ' ', u.last_name) AS account_executive,
    COUNT(*) AS closed_opportunities,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) AS won_opportunities,
    ROUND(100.0 * SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate_pct,
    ROUND(AVG(CASE WHEN o.stage = 'Closed Won' THEN o.net_arr END), 0) AS avg_won_arr,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN o.net_arr ELSE 0 END) AS total_won_arr
FROM raw.opportunities o
JOIN raw.users u
    ON o.owner_id = u.user_id
WHERE o.stage IN ('Closed Won', 'Closed Lost')
  AND u.job_title LIKE '%Account Executive%'
GROUP BY u.user_id, u.first_name, u.last_name
ORDER BY total_won_arr DESC;
-- Finding: Noah Ramirez was the strongest Mid-Market performer: 76.3% win rate and ~$1.66M won ARR.

-- 2.7 Territory performance using state-derived territory
SELECT
    t.territory_name,
    COUNT(*) AS closed_opportunities,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) AS won_opportunities,
    ROUND(100.0 * SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate_pct,
    ROUND(AVG(CASE WHEN o.stage = 'Closed Won' THEN o.net_arr END), 0) AS avg_won_arr,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN o.net_arr ELSE 0 END) AS total_won_arr
FROM raw.opportunities o
JOIN raw.accounts a
    ON o.account_id = a.account_id
JOIN raw.states s
    ON a.state_code = s.state_code
JOIN raw.territories t
    ON s.territory_id = t.territory_id
WHERE o.stage IN ('Closed Won', 'Closed Lost')
GROUP BY t.territory_name
ORDER BY total_won_arr DESC;
-- Finding: West led win rate (64.1%), average won ARR (~$43.7K), and total won ARR (~$1.79M).

-- 2.8 Sales cycle by segment
SELECT
    a.segment,
    COUNT(*) AS won_opportunities,
    ROUND(AVG(o.actual_close_date::date - o.created_at::date), 1) AS avg_sales_cycle_days,
    MIN(o.actual_close_date::date - o.created_at::date) AS shortest_sales_cycle_days,
    MAX(o.actual_close_date::date - o.created_at::date) AS longest_sales_cycle_days
FROM raw.opportunities o
JOIN raw.accounts a
    ON o.account_id = a.account_id
WHERE o.stage = 'Closed Won'
GROUP BY a.segment
ORDER BY avg_sales_cycle_days;
-- Finding: SMB 34.6 days; Mid-Market 67.2; Upper Mid-Market 96.0, closely matching operating-model expectations.

-- 2.9 Stage velocity for won deals
SELECT
    osh.stage,
    COUNT(*) AS stage_visits,
    ROUND(AVG(osh.exited_at::date - osh.entered_at::date), 1) AS avg_days_in_stage
FROM raw.opportunity_stage_history osh
JOIN raw.opportunities o
    ON osh.opportunity_id = o.opportunity_id
WHERE o.stage = 'Closed Won'
  AND osh.exited_at IS NOT NULL
  AND osh.stage NOT IN ('Closed Won', 'Closed Lost')
GROUP BY osh.stage
ORDER BY avg_days_in_stage DESC;

-- 2.10 Won vs lost stage velocity
SELECT
    osh.stage,
    o.stage AS final_outcome,
    COUNT(*) AS stage_visits,
    ROUND(AVG(osh.exited_at::date - osh.entered_at::date), 1) AS avg_days_in_stage
FROM raw.opportunity_stage_history osh
JOIN raw.opportunities o
    ON osh.opportunity_id = o.opportunity_id
WHERE o.stage IN ('Closed Won', 'Closed Lost')
  AND osh.exited_at IS NOT NULL
  AND osh.stage NOT IN ('Closed Won', 'Closed Lost')
GROUP BY osh.stage, o.stage
ORDER BY osh.stage, final_outcome;
-- Finding: Lost deals lingered longer in Discovery, Qualification, Solution Evaluation, and Proposal, with the largest gaps in Qualification and Solution Evaluation.

-- 2.11 Close-date movement by outcome
WITH close_date_summary AS (
    SELECT
        opportunity_id,
        COUNT(*) AS close_date_changes,
        SUM(CASE WHEN new_close_date > old_close_date THEN 1 ELSE 0 END) AS push_count,
        SUM(CASE WHEN new_close_date < old_close_date THEN 1 ELSE 0 END) AS pull_in_count,
        SUM(CASE WHEN new_close_date > old_close_date THEN new_close_date - old_close_date ELSE 0 END) AS total_days_pushed
    FROM raw.opportunity_close_date_history
    GROUP BY opportunity_id
)
SELECT
    CASE
        WHEN o.stage = 'Closed Won' THEN 'Closed Won'
        WHEN o.stage = 'Closed Lost' THEN 'Closed Lost'
        ELSE 'Open'
    END AS opportunity_outcome,
    COUNT(*) AS opportunities,
    SUM(CASE WHEN cds.opportunity_id IS NOT NULL THEN 1 ELSE 0 END) AS opportunities_with_close_date_changes,
    ROUND(100.0 * SUM(CASE WHEN cds.opportunity_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_with_close_date_changes,
    ROUND(AVG(COALESCE(cds.close_date_changes, 0)), 1) AS avg_changes_per_opportunity,
    ROUND(AVG(CASE WHEN cds.push_count > 0 THEN 1.0 * cds.total_days_pushed / cds.push_count END), 1) AS avg_days_per_push
FROM raw.opportunities o
LEFT JOIN close_date_summary cds
    ON o.opportunity_id = cds.opportunity_id
GROUP BY
    CASE
        WHEN o.stage = 'Closed Won' THEN 'Closed Won'
        WHEN o.stage = 'Closed Lost' THEN 'Closed Lost'
        ELSE 'Open'
    END
ORDER BY opportunity_outcome;
-- Finding: 95.7% of Closed Lost, 88.0% of Closed Won, and 76.3% of Open opportunities had at least one close-date change.

-- ============================================================
-- SECTION 3 — FORECAST RELIABILITY
-- ============================================================

-- 3.1 Forecast-category alignment
WITH forecast_alignment AS (
    SELECT
        snapshot_date,
        opportunity_id,
        stage,
        forecast_category,
        CASE
            WHEN stage IN ('Discovery', 'Qualification', 'Solution Evaluation') THEN 'Pipeline'
            WHEN stage IN ('Proposal', 'Negotiation / Legal') THEN 'Best Case'
            WHEN stage = 'Commit' THEN 'Commit'
            WHEN stage IN ('Closed Won', 'Closed Lost') THEN 'Closed'
        END AS expected_forecast_category
    FROM raw.opportunity_forecast_snapshots
)
SELECT
    CASE
        WHEN forecast_category = expected_forecast_category THEN 'Aligned'
        ELSE 'Misaligned'
    END AS forecast_alignment_status,
    COUNT(*) AS snapshot_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_snapshots
FROM forecast_alignment
GROUP BY
    CASE
        WHEN forecast_category = expected_forecast_category THEN 'Aligned'
        ELSE 'Misaligned'
    END
ORDER BY snapshot_count DESC;
-- Finding: 847 of 885 snapshots aligned (95.7%); 38 misaligned (4.3%).

-- 3.2 Misalignment patterns
WITH forecast_alignment AS (
    SELECT
        snapshot_date,
        opportunity_id,
        stage,
        forecast_category,
        CASE
            WHEN stage IN ('Discovery', 'Qualification', 'Solution Evaluation') THEN 'Pipeline'
            WHEN stage IN ('Proposal', 'Negotiation / Legal') THEN 'Best Case'
            WHEN stage = 'Commit' THEN 'Commit'
            WHEN stage IN ('Closed Won', 'Closed Lost') THEN 'Closed'
        END AS expected_forecast_category
    FROM raw.opportunity_forecast_snapshots
)
SELECT
    stage,
    forecast_category AS actual_forecast_category,
    expected_forecast_category,
    COUNT(*) AS misaligned_snapshots
FROM forecast_alignment
WHERE forecast_category IS DISTINCT FROM expected_forecast_category
GROUP BY stage, forecast_category, expected_forecast_category
ORDER BY misaligned_snapshots DESC;
-- Finding: Most misalignment was optimistic, especially early-stage opportunities labeled Commit or Best Case.

-- 3.3 Final pre-close forecast category vs actual outcome
WITH ranked_snapshots AS (
    SELECT
        fs.opportunity_id,
        fs.snapshot_date,
        fs.stage,
        fs.forecast_category,
        fs.net_arr,
        ROW_NUMBER() OVER (
            PARTITION BY fs.opportunity_id
            ORDER BY fs.snapshot_date DESC
        ) AS snapshot_rank
    FROM raw.opportunity_forecast_snapshots fs
    JOIN raw.opportunities o
        ON fs.opportunity_id = o.opportunity_id
    WHERE o.stage IN ('Closed Won', 'Closed Lost')
      AND fs.stage NOT IN ('Closed Won', 'Closed Lost')
      AND fs.snapshot_date <= o.actual_close_date::date
),
final_preclose_forecast AS (
    SELECT
        opportunity_id,
        snapshot_date,
        forecast_category,
        net_arr
    FROM ranked_snapshots
    WHERE snapshot_rank = 1
)
SELECT
    f.forecast_category,
    COUNT(*) AS closed_opportunities,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) AS won_opportunities,
    ROUND(100.0 * SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate_pct,
    SUM(f.net_arr) AS category_arr
FROM final_preclose_forecast f
JOIN raw.opportunities o
    ON f.opportunity_id = o.opportunity_id
GROUP BY f.forecast_category
ORDER BY win_rate_pct DESC;
-- Finding: Commit 86.4% win rate; Best Case 65.8%; Pipeline 31.9%. Coverage: 258 of 265 closed opportunities had a qualifying pre-close snapshot.

-- 3.4 ARR realization by final pre-close forecast
WITH ranked_snapshots AS (
    SELECT
        fs.opportunity_id,
        fs.snapshot_date,
        fs.stage,
        fs.forecast_category,
        fs.net_arr,
        ROW_NUMBER() OVER (
            PARTITION BY fs.opportunity_id
            ORDER BY fs.snapshot_date DESC
        ) AS snapshot_rank
    FROM raw.opportunity_forecast_snapshots fs
    JOIN raw.opportunities o
        ON fs.opportunity_id = o.opportunity_id
    WHERE o.stage IN ('Closed Won', 'Closed Lost')
      AND fs.stage NOT IN ('Closed Won', 'Closed Lost')
      AND fs.snapshot_date <= o.actual_close_date::date
),
final_preclose_forecast AS (
    SELECT
        opportunity_id,
        snapshot_date,
        forecast_category,
        net_arr
    FROM ranked_snapshots
    WHERE snapshot_rank = 1
)
SELECT
    f.forecast_category,
    SUM(f.net_arr) AS category_arr,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN f.net_arr ELSE 0 END) AS won_arr,
    ROUND(100.0 * SUM(CASE WHEN o.stage = 'Closed Won' THEN f.net_arr ELSE 0 END) / SUM(f.net_arr), 1) AS arr_realization_pct
FROM final_preclose_forecast f
JOIN raw.opportunities o
    ON f.opportunity_id = o.opportunity_id
GROUP BY f.forecast_category
ORDER BY arr_realization_pct DESC;
-- Finding: Commit 88.3% ARR realization; Best Case 60.5%; Pipeline 23.5%.

-- ============================================================
-- SECTION 4 — DEAL DESK AND COMMERCIAL GOVERNANCE
-- ============================================================

-- 4.1 Deal Desk flag accuracy
WITH deal_desk_audit AS (
    SELECT
        o.opportunity_id,
        o.deal_desk_required AS actual_deal_desk_required,
        CASE
            WHEN o.discount_pct > 10 THEN TRUE
            WHEN o.net_arr >= 100000 THEN TRUE
            WHEN o.payment_terms <> 'Net 30' THEN TRUE
            WHEN o.billing_schedule <> 'Annual in Advance' THEN TRUE
            WHEN o.custom_pricing_flag = TRUE THEN TRUE
            WHEN o.nonstandard_contract_terms = TRUE THEN TRUE
            WHEN o.implementation_discount_pct > 20 THEN TRUE
            WHEN a.employee_count < 20 THEN TRUE
            WHEN a.employee_count >= 2500 THEN TRUE
            ELSE FALSE
        END AS expected_deal_desk_required
    FROM raw.opportunities o
    JOIN raw.accounts a
        ON o.account_id = a.account_id
)
SELECT
    actual_deal_desk_required,
    expected_deal_desk_required,
    COUNT(*) AS opportunity_count
FROM deal_desk_audit
GROUP BY actual_deal_desk_required, expected_deal_desk_required
ORDER BY opportunity_count DESC;
-- Finding: 224 true/true, 191 false/false, 9 false/true, 1 true/false; 97.6% overall flag accuracy.

-- 4.2 Approval-record coverage for closed deals that should require Deal Desk
WITH deal_desk_expected AS (
    SELECT
        o.opportunity_id,
        o.stage,
        CASE
            WHEN o.discount_pct > 10 THEN TRUE
            WHEN o.net_arr >= 100000 THEN TRUE
            WHEN o.payment_terms <> 'Net 30' THEN TRUE
            WHEN o.billing_schedule <> 'Annual in Advance' THEN TRUE
            WHEN o.custom_pricing_flag = TRUE THEN TRUE
            WHEN o.nonstandard_contract_terms = TRUE THEN TRUE
            WHEN o.implementation_discount_pct > 20 THEN TRUE
            WHEN a.employee_count < 20 THEN TRUE
            WHEN a.employee_count >= 2500 THEN TRUE
            ELSE FALSE
        END AS expected_deal_desk_required
    FROM raw.opportunities o
    JOIN raw.accounts a
        ON o.account_id = a.account_id
    WHERE o.stage IN ('Closed Won', 'Closed Lost')
),
approval_coverage AS (
    SELECT
        dde.opportunity_id,
        dde.stage,
        dde.expected_deal_desk_required,
        COUNT(da.approval_id) AS approval_records
    FROM deal_desk_expected dde
    LEFT JOIN raw.deal_approvals da
        ON dde.opportunity_id = da.opportunity_id
    GROUP BY dde.opportunity_id, dde.stage, dde.expected_deal_desk_required
)
SELECT
    stage,
    expected_deal_desk_required,
    COUNT(*) AS opportunities,
    SUM(CASE WHEN approval_records > 0 THEN 1 ELSE 0 END) AS opportunities_with_approval,
    SUM(CASE WHEN approval_records = 0 THEN 1 ELSE 0 END) AS opportunities_without_approval,
    ROUND(100.0 * SUM(CASE WHEN approval_records > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS approval_coverage_pct
FROM approval_coverage
GROUP BY stage, expected_deal_desk_required
ORDER BY expected_deal_desk_required DESC, stage;
-- Finding: 150 closed opportunities should have required Deal Desk; only 61 had an approval record (40.7% coverage), leaving 89 without auditable approval evidence.

-- 4.3 Approval type and status distribution
SELECT
    approval_type,
    approval_status,
    COUNT(*) AS approval_count
FROM raw.deal_approvals
GROUP BY approval_type, approval_status
ORDER BY approval_type, approval_count DESC;

-- 4.4 Discount approval-path compliance
WITH discount_approval_audit AS (
    SELECT
        da.opportunity_id,
        MAX(da.requested_discount_pct) AS requested_discount_pct,
        BOOL_OR(u.job_title IN ('SMB Sales Manager', 'Mid-Market Sales Manager')) AS has_sales_manager,
        BOOL_OR(u.job_title = 'Director of Sales') AS has_director_sales,
        BOOL_OR(u.job_title = 'Revenue Operations Manager') AS has_revops,
        BOOL_OR(u.job_title = 'VP of Revenue') AS has_vp_revenue,
        BOOL_OR(u.job_title = 'Finance Manager') AS has_finance
    FROM raw.deal_approvals da
    LEFT JOIN raw.users u
        ON da.approver_user_id = u.user_id
    WHERE da.approval_type = 'Discount'
    GROUP BY da.opportunity_id
),
discount_compliance AS (
    SELECT
        opportunity_id,
        requested_discount_pct,
        CASE
            WHEN requested_discount_pct > 25 AND has_vp_revenue = TRUE AND has_finance = TRUE THEN 'Compliant'
            WHEN requested_discount_pct > 20 AND requested_discount_pct <= 25 AND has_director_sales = TRUE AND has_revops = TRUE THEN 'Compliant'
            WHEN requested_discount_pct > 10 AND requested_discount_pct <= 20 AND has_sales_manager = TRUE THEN 'Compliant'
            WHEN requested_discount_pct <= 10 THEN 'Compliant'
            ELSE 'Missing Required Approver'
        END AS approval_path_status
    FROM discount_approval_audit
)
SELECT
    CASE
        WHEN requested_discount_pct > 25 THEN '>25% - VP + Finance'
        WHEN requested_discount_pct > 20 THEN '>20-25% - Director + RevOps'
        WHEN requested_discount_pct > 10 THEN '>10-20% - Sales Manager'
        ELSE '0-10% - AE Discretion'
    END AS discount_band,
    approval_path_status,
    COUNT(*) AS opportunity_count
FROM discount_compliance
GROUP BY
    CASE
        WHEN requested_discount_pct > 25 THEN '>25% - VP + Finance'
        WHEN requested_discount_pct > 20 THEN '>20-25% - Director + RevOps'
        WHEN requested_discount_pct > 10 THEN '>10-20% - Sales Manager'
        ELSE '0-10% - AE Discretion'
    END,
    approval_path_status
ORDER BY discount_band, approval_path_status;
-- Finding: 10-20% requests were 24/24 compliant; only 3/24 at >20-25% and 2/10 at >25% had evidence of the full required approval chain.

-- 4.5 Discount band vs win rate
SELECT
    CASE
        WHEN discount_pct <= 10 THEN '0-10%'
        WHEN discount_pct <= 20 THEN '>10-20%'
        WHEN discount_pct <= 25 THEN '>20-25%'
        ELSE '>25%'
    END AS discount_band,
    COUNT(*) AS closed_opportunities,
    SUM(CASE WHEN stage = 'Closed Won' THEN 1 ELSE 0 END) AS won_opportunities,
    ROUND(100.0 * SUM(CASE WHEN stage = 'Closed Won' THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate_pct,
    ROUND(AVG(discount_pct), 1) AS avg_discount_pct,
    ROUND(AVG(CASE WHEN stage = 'Closed Won' THEN net_arr END), 0) AS avg_won_arr
FROM raw.opportunities
WHERE stage IN ('Closed Won', 'Closed Lost')
GROUP BY
    CASE
        WHEN discount_pct <= 10 THEN '0-10%'
        WHEN discount_pct <= 20 THEN '>10-20%'
        WHEN discount_pct <= 25 THEN '>20-25%'
        ELSE '>25%'
    END
ORDER BY avg_discount_pct;
-- Finding: Up to 25%, win rates stayed near 55-58%; the >25% bucket was higher but contained only 12 closed opportunities.

-- 4.6 Discount band vs win rate by segment
SELECT
    a.segment,
    CASE
        WHEN o.discount_pct <= 10 THEN '0-10%'
        WHEN o.discount_pct <= 20 THEN '>10-20%'
        WHEN o.discount_pct <= 25 THEN '>20-25%'
        ELSE '>25%'
    END AS discount_band,
    COUNT(*) AS closed_opportunities,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) AS won_opportunities,
    ROUND(100.0 * SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) / COUNT(*), 1) AS win_rate_pct,
    ROUND(AVG(o.discount_pct), 1) AS avg_discount_pct
FROM raw.opportunities o
JOIN raw.accounts a
    ON o.account_id = a.account_id
WHERE o.stage IN ('Closed Won', 'Closed Lost')
  AND a.segment IS NOT NULL
GROUP BY
    a.segment,
    CASE
        WHEN o.discount_pct <= 10 THEN '0-10%'
        WHEN o.discount_pct <= 20 THEN '>10-20%'
        WHEN o.discount_pct <= 25 THEN '>20-25%'
        ELSE '>25%'
    END
ORDER BY a.segment, avg_discount_pct;
-- Finding: After controlling for segment, higher discounting still did not show a consistent relationship with win rate.

-- ============================================================
-- SECTION 5 — LEAD FUNNEL, ROUTING, AND LIFECYCLE
-- ============================================================

-- 5.1 Lifecycle/status distribution
SELECT
    lifecycle_stage,
    lead_status,
    COUNT(*) AS lead_count,
    SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END) AS converted_leads,
    ROUND(100.0 * SUM(CASE WHEN is_converted = TRUE THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate_pct
FROM raw.leads
GROUP BY lifecycle_stage, lead_status
ORDER BY lifecycle_stage, lead_count DESC;

-- 5.2 Lead source conversion and Closed Won ARR
SELECT
    l.lead_source,
    COUNT(*) AS total_leads,
    SUM(CASE WHEN l.is_converted = TRUE THEN 1 ELSE 0 END) AS converted_leads,
    ROUND(100.0 * SUM(CASE WHEN l.is_converted = TRUE THEN 1 ELSE 0 END) / COUNT(*), 1) AS lead_conversion_rate_pct,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN 1 ELSE 0 END) AS closed_won_opportunities,
    SUM(CASE WHEN o.stage = 'Closed Won' THEN o.net_arr ELSE 0 END) AS closed_won_arr
FROM raw.leads l
LEFT JOIN raw.opportunities o
    ON l.converted_opportunity_id = o.opportunity_id
GROUP BY l.lead_source
ORDER BY closed_won_arr DESC;
-- Finding: Partner Referral had the highest lead conversion rate (33.3%); Content Download produced the highest Closed Won ARR ($474,264). 22 leads had missing or non-standard source values.

-- 5.3 MQL response-SLA measurability audit
SELECT
    COUNT(*) AS mql_leads,
    SUM(CASE WHEN first_response_at < mql_at THEN 1 ELSE 0 END) AS responded_before_mql,
    SUM(CASE WHEN first_response_at >= mql_at THEN 1 ELSE 0 END) AS responded_at_or_after_mql,
    SUM(CASE WHEN first_response_at IS NULL THEN 1 ELSE 0 END) AS missing_first_response,
    SUM(
        CASE
            WHEN first_response_at >= mql_at
             AND EXTRACT(EPOCH FROM (first_response_at - mql_at)) / 3600.0 <= 4
                THEN 1
            ELSE 0
        END
    ) AS measurable_responses_within_4_hours,
    SUM(
        CASE
            WHEN first_response_at >= mql_at
             AND EXTRACT(EPOCH FROM (first_response_at - mql_at)) / 3600.0 > 4
                THEN 1
            ELSE 0
        END
    ) AS measurable_responses_over_4_hours
FROM raw.leads
WHERE mql_at IS NOT NULL
  AND mql_at < DATE '2026-09-28';
-- Finding: 449 of 829 MQLs were already responded to before MQL; only 332 had a measurable post-MQL first response, so first_response_at cannot measure the four-business-hour SLA consistently.

-- 5.4 Lead routing audit
WITH lead_routing AS (
    SELECT
        l.lead_id,
        l.segment AS lead_segment,
        l.state_code,
        l.owner_id,
        u.job_title,
        u.segment AS owner_segment,
        u.territory_id AS owner_territory_id,
        s.territory_id AS expected_territory_id,
        CASE
            WHEN l.segment = 'SMB' THEN 'SMB'
            WHEN l.segment IN ('Mid-Market', 'Upper Mid-Market') THEN 'MM'
            ELSE NULL
        END AS expected_owner_segment
    FROM raw.leads l
    LEFT JOIN raw.users u
        ON l.owner_id = u.user_id
    LEFT JOIN raw.states s
        ON l.state_code = s.state_code
),
routing_audit AS (
    SELECT
        *,
        CASE
            WHEN owner_id IS NULL THEN 'Unassigned'
            WHEN expected_owner_segment IS NULL THEN 'Needs Review - Segment'
            WHEN expected_territory_id IS NULL THEN 'Needs Review - Territory'
            WHEN owner_segment IS DISTINCT FROM expected_owner_segment THEN 'Wrong Segment'
            WHEN job_title LIKE '%Account Executive%'
             AND owner_territory_id IS DISTINCT FROM expected_territory_id THEN 'Wrong AE Territory'
            WHEN job_title LIKE '%Account Executive%'
              OR job_title = 'Sales Development Representative' THEN 'Routing Compatible'
            ELSE 'Unexpected Owner Role'
        END AS routing_status
    FROM lead_routing
)
SELECT
    routing_status,
    COUNT(*) AS lead_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_leads
FROM routing_audit
GROUP BY routing_status
ORDER BY lead_count DESC;
-- Finding: 87.5% routing-compatible; 65 unassigned; 50 wrong AE territory; 27 wrong segment; 20 additional records lacked enough routing attributes to fully validate.

-- 5.5 Qualified-lead aging proxy
WITH lead_aging AS (
    SELECT
        lead_id,
        lifecycle_stage,
        lead_status,
        CASE
            WHEN lifecycle_stage = 'Sales Qualified Lead' AND sql_at IS NOT NULL THEN DATE '2026-09-28' - sql_at::date
            WHEN lifecycle_stage = 'Marketing Qualified Lead' AND mql_at IS NOT NULL THEN DATE '2026-09-28' - mql_at::date
            ELSE NULL
        END AS days_in_current_qualified_stage
    FROM raw.leads
    WHERE is_converted = FALSE
      AND lifecycle_stage IN ('Marketing Qualified Lead', 'Sales Qualified Lead')
)
SELECT
    lifecycle_stage,
    lead_status,
    COUNT(*) AS lead_count,
    ROUND(AVG(days_in_current_qualified_stage), 1) AS avg_days_in_stage,
    SUM(CASE WHEN days_in_current_qualified_stage > 30 THEN 1 ELSE 0 END) AS over_30_days,
    ROUND(100.0 * SUM(CASE WHEN days_in_current_qualified_stage > 30 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_over_30_days
FROM lead_aging
GROUP BY lifecycle_stage, lead_status
ORDER BY pct_over_30_days DESC, lead_count DESC;
-- Finding: 506 of 529 non-converted MQL/SQL records (~95.7%) were more than 30 days past their qualification milestone.

-- 5.6 Disqualification reasons
SELECT
    disqualification_reason,
    COUNT(*) AS disqualified_leads,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_disqualified
FROM raw.leads
WHERE lead_status = 'Disqualified'
GROUP BY disqualification_reason
ORDER BY disqualified_leads DESC;
-- Finding: 48% of disqualifications were fit-related (Company Too Small, Enterprise Requirements, Not a Fit); ~31.6% reflected no response, duplicates, or bad contact data.

-- ============================================================
-- SECTION 6 — SALES ACTIVITY
-- ============================================================

-- 6.1 Activity intensity by closed outcome
WITH opportunity_activity AS (
    SELECT
        o.opportunity_id,
        o.stage,
        COUNT(a.activity_id) AS completed_activities,
        COUNT(*) FILTER (WHERE a.activity_type = 'Call') AS calls,
        COUNT(*) FILTER (WHERE a.activity_type = 'Email') AS emails,
        COUNT(*) FILTER (WHERE a.activity_type = 'Meeting') AS meetings
    FROM raw.opportunities o
    LEFT JOIN raw.activities a
        ON o.opportunity_id = a.opportunity_id
       AND a.completed_flag = TRUE
    WHERE o.stage IN ('Closed Won', 'Closed Lost')
    GROUP BY o.opportunity_id, o.stage
)
SELECT
    stage AS final_outcome,
    COUNT(*) AS closed_opportunities,
    ROUND(AVG(completed_activities), 1) AS avg_completed_activities,
    ROUND(AVG(calls), 1) AS avg_calls,
    ROUND(AVG(emails), 1) AS avg_emails,
    ROUND(AVG(meetings), 1) AS avg_meetings,
    SUM(CASE WHEN completed_activities = 0 THEN 1 ELSE 0 END) AS opportunities_with_no_activity
FROM opportunity_activity
GROUP BY stage
ORDER BY stage;
-- Finding: Closed Won opportunities averaged 9.1 completed activities vs 6.8 for Closed Lost; this is an association, not proof of causation.

-- ============================================================
-- SECTION 7 — FINAL CRM QA
-- ============================================================

-- 7.1 Potential duplicate identifiers
SELECT
    'Lead Email' AS duplicate_check,
    COUNT(*) AS duplicate_groups
FROM (
    SELECT email
    FROM raw.leads
    WHERE email IS NOT NULL
    GROUP BY email
    HAVING COUNT(*) > 1
) x
UNION ALL
SELECT
    'Contact Email',
    COUNT(*)
FROM (
    SELECT email
    FROM raw.contacts
    WHERE email IS NOT NULL
    GROUP BY email
    HAVING COUNT(*) > 1
) x
UNION ALL
SELECT
    'Account Website',
    COUNT(*)
FROM (
    SELECT website
    FROM raw.accounts
    WHERE website IS NOT NULL
    GROUP BY website
    HAVING COUNT(*) > 1
) x
UNION ALL
SELECT
    'Account Name',
    COUNT(*)
FROM (
    SELECT account_name
    FROM raw.accounts
    WHERE account_name IS NOT NULL
    GROUP BY account_name
    HAVING COUNT(*) > 1
) x;
-- Finding: 12 repeated lead-email groups, 2 repeated contact-email groups, 5 repeated account websites, 0 duplicate account-name groups.

-- 7.2 Open-opportunity critical-field completeness
SELECT
    COUNT(*) AS open_opportunities,
    SUM(CASE WHEN owner_id IS NULL THEN 1 ELSE 0 END) AS missing_owner,
    SUM(CASE WHEN account_id IS NULL THEN 1 ELSE 0 END) AS missing_account,
    SUM(CASE WHEN stage IS NULL THEN 1 ELSE 0 END) AS missing_stage,
    SUM(CASE WHEN net_arr IS NULL THEN 1 ELSE 0 END) AS missing_arr,
    SUM(CASE WHEN expected_close_date IS NULL THEN 1 ELSE 0 END) AS missing_close_date,
    SUM(CASE WHEN next_step IS NULL OR TRIM(next_step) = '' THEN 1 ELSE 0 END) AS missing_next_step,
    SUM(CASE WHEN last_activity_date IS NULL THEN 1 ELSE 0 END) AS missing_last_activity,
    SUM(CASE WHEN lead_source IS NULL OR TRIM(lead_source) = '' THEN 1 ELSE 0 END) AS missing_source,
    SUM(CASE WHEN forecast_category IS NULL THEN 1 ELSE 0 END) AS missing_forecast_category,
    SUM(
        CASE
            WHEN owner_id IS NULL
              OR account_id IS NULL
              OR stage IS NULL
              OR net_arr IS NULL
              OR expected_close_date IS NULL
              OR next_step IS NULL
              OR TRIM(next_step) = ''
              OR last_activity_date IS NULL
              OR lead_source IS NULL
              OR TRIM(lead_source) = ''
              OR forecast_category IS NULL
                THEN 1
            ELSE 0
        END
    ) AS open_opportunities_with_any_missing_critical_field
FROM raw.opportunities
WHERE stage NOT IN ('Closed Won', 'Closed Lost');
-- Finding: 30 of 160 open opportunities (18.8%) had at least one critical completeness gap; source attribution was the largest issue (19), followed by next step (9) and ownership (3).
