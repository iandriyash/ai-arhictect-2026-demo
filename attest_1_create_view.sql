-- Витрина 1-й промежуточной аттестации
-- Тема: прогноз просрочки по розничному кредиту
-- Гранулярность: 1 строка = 1 кредит, по которому есть платежи
-- Целевая: is_overdue = 1, если по кредиту был хотя бы один платёж со статусом LATE (id = 2)

CREATE OR REPLACE VIEW public.v_loan_overdue_mart AS
WITH pay AS (
    SELECT
        loan_id,
        COUNT(*) AS payments_cnt,
        COUNT(*) FILTER (WHERE payment_status_id = 2) AS late_cnt,
        COALESCE(SUM(late_fee_amount), 0) AS late_fee_sum,
        AVG((payment_date - due_date)) FILTER (WHERE payment_date > due_date) AS avg_delay_days
    FROM public.loan_payments
    GROUP BY loan_id
),
emp AS (
    SELECT DISTINCT ON (customer_id)
        customer_id,
        employment_status_id,
        industry_id,
        annual_income,
        job_title
    FROM public.customer_employment
    ORDER BY customer_id, valid_from DESC NULLS LAST
)
SELECT
    l.loan_id,
    l.customer_id,
    l.loan_product_id,
    l.loan_status_id,
    ls.status_code AS loan_status,
    l.principal_amount,
    l.interest_rate,
    l.term_months,
    l.disbursement_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth))::INT AS customer_age,
    c.gender_id,
    c.customer_status_id,
    e.employment_status_id,
    e.industry_id,
    e.annual_income,
    CASE
        WHEN e.annual_income IS NULL OR e.annual_income = 0 THEN NULL
        ELSE l.principal_amount / e.annual_income
    END AS loan_to_income,
    p.payments_cnt,
    p.late_cnt,
    p.late_fee_sum,
    p.avg_delay_days,
    CASE WHEN p.late_cnt > 0 THEN 1 ELSE 0 END AS is_overdue
FROM public.loans l
INNER JOIN pay p
    ON p.loan_id = l.loan_id
INNER JOIN public.customers c
    ON c.customer_id = l.customer_id
LEFT JOIN emp e
    ON e.customer_id = l.customer_id
LEFT JOIN public.loan_statuses ls
    ON ls.loan_status_id = l.loan_status_id;
