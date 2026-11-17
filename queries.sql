-- 0. CHUAN BI: view chuan hoa thoi gian (SQLite)

DROP VIEW IF EXISTS user_kpi;
DROP VIEW IF EXISTS stg_events;
DROP VIEW IF EXISTS stg_users;

CREATE VIEW stg_users AS
SELECT *, DATE(registered_at) AS d0
FROM users;

CREATE VIEW stg_events AS
SELECT e.*,
       DATE(e.occurred_at) AS event_date,
       CAST(JULIANDAY(DATE(e.occurred_at)) - JULIANDAY(u.d0) AS INTEGER) AS day_n
FROM events AS e
JOIN stg_users AS u USING (user_id);

-- 1. KIEM TRA CHAT LUONG DU LIEU

SELECT
  (SELECT COUNT(*) - COUNT(DISTINCT user_id) FROM users) AS dup_users,
  (SELECT COUNT(*) - COUNT(DISTINCT event_id) FROM events) AS dup_events,
  (SELECT COUNT(*)
   FROM events AS e
   LEFT JOIN users AS u USING (user_id)
   WHERE u.user_id IS NULL) AS orphan_events,
  (SELECT COUNT(*) FROM stg_events WHERE day_n < 0) AS events_before_signup;

SELECT COUNT(*) AS users_not_exactly_one_signup
FROM (
  SELECT u.user_id
  FROM users AS u
  LEFT JOIN events AS e
    ON e.user_id = u.user_id
   AND e.event_name = 'sign_up'
  GROUP BY u.user_id
  HAVING COUNT(e.event_id) <> 1
);

-- 2. VIEW KPI CAP USER

CREATE VIEW user_kpi AS
SELECT
  u.user_id,
  u.acquisition_channel,
  u.device_type,
  u.learning_goal,
  u.experience_level,
  u.province,
  u.d0,
  DATE(u.d0, '-' || ((CAST(STRFTIME('%w', u.d0) AS INTEGER) + 6) % 7) || ' days') AS signup_week,
  MAX(CASE WHEN e.event_name = 'start_lesson' AND e.day_n BETWEEN 0 AND 7 THEN 1 ELSE 0 END) AS activated,
  MAX(CASE WHEN e.event_name IN (
    'log_in', 'view_content', 'start_lesson', 'complete_lesson',
    'submit_quiz', 'check_in', 'join_campaign', 'share_content'
  ) AND e.day_n = 7 THEN 1 ELSE 0 END) AS d7_retained,
  MAX(CASE WHEN e.event_name IN (
    'log_in', 'view_content', 'start_lesson', 'complete_lesson',
    'submit_quiz', 'check_in', 'join_campaign', 'share_content'
  ) AND e.day_n BETWEEN 1 AND 7 THEN 1 ELSE 0 END) AS active_d1_d7,
  MAX(CASE WHEN e.event_name = 'complete_lesson' THEN 1 ELSE 0 END) AS completed,
  MAX(CASE WHEN e.event_name = 'join_campaign' THEN 1 ELSE 0 END) AS joined_campaign,
  SUM(CASE WHEN e.event_name = 'complete_lesson' THEN 1 ELSE 0 END) AS n_complete
FROM stg_users AS u
LEFT JOIN stg_events AS e USING (user_id)
GROUP BY u.user_id;

-- 3. KPI TONG QUAN

SELECT
  COUNT(*) AS users,
  ROUND(100.0 * AVG(activated), 1) AS activation_pct,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct,
  ROUND(100.0 * AVG(active_d1_d7), 1) AS active_d1_d7_pct,
  ROUND(100.0 * AVG(completed), 1) AS completion_pct
FROM user_kpi;

-- 4. FUNNEL USER DUY NHAT

WITH f AS (
  SELECT
    u.user_id,
    MAX(CASE WHEN e.event_name = 'sign_up' THEN 1 ELSE 0 END) AS s1,
    MAX(CASE WHEN e.event_name = 'log_in' THEN 1 ELSE 0 END) AS s2,
    MAX(CASE WHEN e.event_name = 'view_content' THEN 1 ELSE 0 END) AS s3,
    MAX(CASE WHEN e.event_name = 'start_lesson' THEN 1 ELSE 0 END) AS s4,
    MAX(CASE WHEN e.event_name = 'complete_lesson' THEN 1 ELSE 0 END) AS s5
  FROM users AS u
  LEFT JOIN events AS e USING (user_id)
  GROUP BY u.user_id
),
steps AS (
  SELECT 1 AS ord, 'sign_up' AS step, SUM(s1) AS users FROM f
  UNION ALL SELECT 2, 'log_in', SUM(s2) FROM f
  UNION ALL SELECT 3, 'view_content', SUM(s3) FROM f
  UNION ALL SELECT 4, 'start_lesson', SUM(s4) FROM f
  UNION ALL SELECT 5, 'complete_lesson', SUM(s5) FROM f
)
SELECT
  step,
  users,
  ROUND(100.0 * users / LAG(users) OVER (ORDER BY ord), 1) AS pct_vs_prev,
  ROUND(100.0 * users / FIRST_VALUE(users) OVER (ORDER BY ord), 1) AS pct_vs_signup
FROM steps
ORDER BY ord;

-- Funnel theo kenh (co the thay acquisition_channel bang device_type, learning_goal...)
WITH f AS (
  SELECT
    u.acquisition_channel AS ch,
    u.user_id,
    MAX(CASE WHEN e.event_name = 'log_in' THEN 1 ELSE 0 END) AS s2,
    MAX(CASE WHEN e.event_name = 'view_content' THEN 1 ELSE 0 END) AS s3,
    MAX(CASE WHEN e.event_name = 'start_lesson' THEN 1 ELSE 0 END) AS s4,
    MAX(CASE WHEN e.event_name = 'complete_lesson' THEN 1 ELSE 0 END) AS s5
  FROM users AS u
  LEFT JOIN events AS e USING (user_id)
  GROUP BY u.acquisition_channel, u.user_id
)
SELECT
  ch,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(s2), 1) AS log_in_pct,
  ROUND(100.0 * AVG(s3), 1) AS view_pct,
  ROUND(100.0 * AVG(s4), 1) AS start_pct,
  ROUND(100.0 * AVG(s5), 1) AS complete_pct
FROM f
GROUP BY ch
ORDER BY users DESC;

-- 5. ACTIVATION VA D7 THEO NHOM

SELECT
  acquisition_channel AS segment,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(activated), 1) AS activation_pct,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct,
  ROUND(100.0 * AVG(completed), 1) AS completion_pct
FROM user_kpi
GROUP BY segment
ORDER BY users DESC;

SELECT
  acquisition_channel,
  device_type,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(activated), 1) AS activation_pct,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct
FROM user_kpi
GROUP BY acquisition_channel, device_type
ORDER BY acquisition_channel, device_type;

-- 6. DUONG CONG HOAT DONG D0..D15

SELECT
  day_n,
  COUNT(DISTINCT user_id) AS active_users,
  ROUND(
    100.0 * COUNT(DISTINCT user_id) / (SELECT COUNT(*) FROM users),
    1
  ) AS pct_users
FROM stg_events
WHERE event_name <> 'sign_up'
  AND day_n BETWEEN 0 AND 15
GROUP BY day_n
ORDER BY day_n;

-- User chi hoat dong trong D0 (khong quay lai)
WITH user_activity AS (
  SELECT
    u.user_id,
    MAX(CASE
      WHEN e.event_name <> 'sign_up' AND e.day_n = 0 THEN 1
      ELSE 0
    END) AS has_d0_activity,
    MAX(CASE
      WHEN e.event_name <> 'sign_up' AND e.day_n > 0 THEN 1
      ELSE 0
    END) AS has_post_d0_activity,
    MAX(CASE
      WHEN e.event_name <> 'sign_up' THEN 1
      ELSE 0
    END) AS has_non_signup_activity
  FROM stg_users AS u
  LEFT JOIN stg_events AS e USING (user_id)
  GROUP BY u.user_id
)
SELECT
  SUM(CASE
    WHEN has_d0_activity = 1 AND has_post_d0_activity = 0 THEN 1
    ELSE 0
  END) AS only_d0_users,
  SUM(CASE WHEN has_non_signup_activity = 0 THEN 1 ELSE 0 END) AS signup_only_users,
  SUM(CASE WHEN has_post_d0_activity = 0 THEN 1 ELSE 0 END) AS no_activity_after_d0_users,
  ROUND(
    100.0 * SUM(CASE WHEN has_post_d0_activity = 0 THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS no_activity_after_d0_pct,
  SUM(CASE WHEN has_post_d0_activity = 1 THEN 1 ELSE 0 END) AS returned_after_d0_users,
  ROUND(
    100.0 * SUM(CASE WHEN has_post_d0_activity = 1 THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS returned_after_d0_pct
FROM user_activity;

-- 7. COHORT THEO TUAN DANG KY

SELECT
  signup_week,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(activated), 1) AS activation_pct,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct
FROM user_kpi
GROUP BY signup_week
ORDER BY signup_week;

-- 8. TIME-TO-FIRST-LESSON (trung vi, phut)

WITH first_lesson AS (
  SELECT
    u.user_id,
    CAST((
      STRFTIME('%s', SUBSTR(MIN(e.occurred_at), 1, 16) || ':00') -
      STRFTIME('%s', SUBSTR(u.registered_at, 1, 16) || ':00')
    ) / 60 AS INTEGER) AS mins
  FROM users AS u
  JOIN events AS e USING (user_id)
  WHERE e.event_name = 'start_lesson'
  GROUP BY u.user_id, u.registered_at
),
ranked AS (
  SELECT
    mins,
    ROW_NUMBER() OVER (ORDER BY mins) AS rn,
    COUNT(*) OVER () AS n
  FROM first_lesson
)
SELECT
  COUNT(*) AS starters,
  ROUND(AVG(CASE WHEN rn IN ((n + 1) / 2, (n + 2) / 2) THEN mins END), 1) AS median_minutes,
  ROUND(100.0 * SUM(CASE WHEN mins <= 60 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_within_1h
FROM ranked;

-- 9. D7 THEO TRANG THAI ACTIVATION

SELECT
  activated,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct
FROM user_kpi
GROUP BY activated;

-- 10. D7 THEO SO BAI DA HOAN THANH

SELECT
  MIN(n_complete, 3) AS lessons_completed,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct
FROM user_kpi
GROUP BY MIN(n_complete, 3)
ORDER BY lessons_completed;

-- 11. CAMPAIGN

SELECT
  joined_campaign,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(activated), 1) AS activation_pct,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct
FROM user_kpi
GROUP BY joined_campaign;

-- 11b. Trong nhom da activate
SELECT
  joined_campaign,
  COUNT(*) AS users,
  ROUND(100.0 * AVG(d7_retained), 1) AS d7_pct
FROM user_kpi
WHERE activated = 1
GROUP BY joined_campaign;

-- 11c. Theo tung campaign, moi user chi tinh mot lan moi campaign
WITH participants AS (
  SELECT DISTINCT campaign_id, user_id
  FROM events
  WHERE event_name = 'join_campaign'
    AND campaign_id IS NOT NULL
)
SELECT
  c.campaign_id,
  c.campaign_name,
  COUNT(*) AS participants,
  ROUND(100.0 * AVG(k.d7_retained), 1) AS d7_pct,
  ROUND(100.0 * AVG(k.activated), 1) AS activation_pct
FROM participants AS p
JOIN campaigns AS c USING (campaign_id)
JOIN user_kpi AS k USING (user_id)
GROUP BY c.campaign_id, c.campaign_name
ORDER BY c.campaign_id;

-- 11d. Thoi diem tham gia campaign (ngay sau dang ky)
SELECT day_n, COUNT(*) AS joins
FROM stg_events
WHERE event_name = 'join_campaign'
GROUP BY day_n
ORDER BY day_n;

-- 12. FUNNEL THEO BAI HOC

SELECT
  c.content_id,
  c.content_title,
  c.level,
  COUNT(DISTINCT CASE WHEN e.event_name = 'view_content' THEN e.user_id END) AS viewers,
  COUNT(DISTINCT CASE WHEN e.event_name = 'start_lesson' THEN e.user_id END) AS starters,
  COUNT(DISTINCT CASE WHEN e.event_name = 'complete_lesson' THEN e.user_id END) AS completers
FROM events AS e
JOIN content AS c USING (content_id)
GROUP BY c.content_id, c.content_title, c.level
ORDER BY c.content_id;
