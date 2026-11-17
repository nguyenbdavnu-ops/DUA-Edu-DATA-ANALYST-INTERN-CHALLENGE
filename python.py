
import sys, pandas as pd
from scipy import stats
x = pd.read_excel(sys.argv[1] if len(sys.argv) > 1 else 'DUA_Edu_Intern.xlsx', sheet_name=None)
u, e = x['Users'].copy(), x['Events'].copy()
u['reg'] = pd.to_datetime(u.registered_at); u['d0'] = u.reg.dt.normalize()
e['t'] = pd.to_datetime(e.occurred_at)
e = e.merge(u[['user_id', 'd0']], on='user_id'); e['off'] = (e.t.dt.normalize() - e.d0).dt.days
ACTIVE = ['log_in','view_content','start_lesson','complete_lesson','submit_quiz','check_in','join_campaign','share_content']
u['act'] = u.user_id.isin(e[(e.event_name == 'start_lesson') & (e.off <= 7)].user_id)
u['d7'] = u.user_id.isin(e[e.event_name.isin(ACTIVE) & (e.off == 7)].user_id)
u['joined'] = u.user_id.isin(e[e.event_name == 'join_campaign'].user_id)
print('Activation %.1f%% | D7 %.1f%%' % (100*u.act.mean(), 100*u.d7.mean()))
for s in ['sign_up','log_in','view_content','start_lesson','complete_lesson']:
    print(s, e[e.event_name == s].user_id.nunique())
for col in ['acquisition_channel','device_type','province']:
    print(u.groupby(col).agg(n=('user_id','count'), act=('act','mean'), d7=('d7','mean')).round(3))
    print('chi2 p(D7) =', round(stats.chi2_contingency(pd.crosstab(u[col], u.d7))[1], 3))
print(u.groupby('joined').agg(n=('user_id','count'), act=('act','mean'), d7=('d7','mean')).round(3))

# --- Nhóm không có hoạt động nào sau D0
act = e[e.event_name.isin(ACTIVE)]
nonsu = e[e.event_name != 'sign_up'].groupby('user_id').off.max()
only_d0, signup_only = int((nonsu == 0).sum()), int(len(u) - len(nonsu))
no_return = int((~u.user_id.isin(act[act.off >= 1].user_id)).sum())
print('Chi hoat dong D0:', only_d0, '| Chi dang ky:', signup_only, '| Tong:', only_d0 + signup_only, '| Kiem tra:', no_return)

# --- Funnel CÓ ÉP THỨ TỰ thời gian
STEPS = ['sign_up', 'log_in', 'view_content', 'start_lesson', 'complete_lesson']
ft = e[e.event_name.isin(STEPS)].groupby(['user_id', 'event_name']).t.min().unstack()[STEPS]
cur, ordered = ft['sign_up'].notna(), []
ordered.append(int(cur.sum()))
for i in range(1, 5):
    cur = cur & ft[STEPS[i]].notna() & (ft[STEPS[i]] >= ft[STEPS[i-1]]); ordered.append(int(cur.sum()))
print('Funnel co ep thu tu:', ordered)

# --- Campaign có xét thời điểm tham gia
first_join = e[e.event_name == 'join_campaign'].groupby('user_id').off.min()
u['first_join_day'] = u.user_id.map(first_join)
print('Tham gia lan dau sau D7:', int((first_join > 7).sum()), '/', len(first_join), '| dung D7:', int((first_join == 7).sum()))
u['join_timing'] = u.first_join_day.map(lambda d: '3. Khong tham gia' if pd.isna(d) else ('1. Truoc D7 (D0-D6)' if d <= 6 else '2. Tu D7 tro di'))
print(u.groupby('join_timing').agg(users=('user_id', 'count'), act=('act', 'mean'), d7=('d7', 'mean')).round(3))
sub = u[~u.join_timing.str.startswith('2')]
print('p(D7: truoc D7 vs khong tham gia) = %.4f' % stats.chi2_contingency(pd.crosstab(sub.join_timing, sub.d7))[1])
