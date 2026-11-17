# DUA Edu - Data Analyst Intern Challenge

Phân tích dữ liệu hoạt động của nền tảng học tập DUA Edu bằng Python và SQLite. Dữ liệu trong bộ đề được mô tả là dữ liệu mô phỏng; không dùng các kết quả này để suy luận về người dùng thật.

## Nội dung

- [`data/DUA Edu_Intern.xlsx`](data/DUA%20Edu_Intern.xlsx): workbook nguồn, gồm các sheet dữ liệu người học, sự kiện và danh mục.
- [`data/dua_edu_intern.db`](data/dua_edu_intern.db): bản SQLite của bộ dữ liệu.
- [`python.py`](python.py): tính KPI, funnel có xét thứ tự thời gian, phân tích nhóm và thời điểm tham gia campaign.
- [`queries.sql`](queries.sql): truy vấn kiểm tra chất lượng dữ liệu, KPI, retention, cohort, campaign và nội dung học.

## Cách chạy

Cần Python 3, SQLite và các thư viện `pandas`, `scipy`, `openpyxl`.

```bash
python -m pip install pandas scipy openpyxl
python python.py "data/DUA Edu_Intern.xlsx"
sqlite3 data/dua_edu_intern.db < queries.sql
```

Có thể truyền đường dẫn workbook khác làm đối số cho `python.py`. Nếu bỏ đối số, script tìm `DUA_Edu_Intern.xlsx` trong thư mục hiện tại.

Script SQL tạo lại các view staging và `user_kpi` khi chạy, nên có thể chạy lại trên database đã có các view này.

## Kết quả chính

Đối chiếu Python và SQL trên bộ dữ liệu đi kèm cho các chỉ số chung:

- **850 người học**, **9.455 sự kiện**; kiểm tra không phát hiện user/event trùng, event mồ côi, event trước ngày đăng ký, hoặc user thiếu/thừa event `sign_up`.
- **Activation: 73,5%**; **D7 retention: 23,8%**.
- Funnel theo user: `sign_up` 850 → `log_in` 816 → `view_content` 761 → `start_lesson` 688 → `complete_lesson` 550. Kết quả funnel có thứ tự trong Python trùng với các số lượng từng bước trong SQL.
- **104 người (12,2%) không có hoạt động sau D0**: 70 có hoạt động ngoài `sign_up` chỉ trong D0 và 34 chỉ có `sign_up`. **746 người (87,8%)** có hoạt động sau D0.
- **688** người bắt đầu bài học; trung vị thời gian tới bài học đầu tiên là **20 phút**, và **75,3%** bắt đầu trong vòng một giờ.
- **289** người tham gia campaign và 561 người không tham gia. Các tỷ lệ theo nhóm là mô tả, không chứng minh quan hệ nhân quả.

## Ghi chú về cách diễn giải

- Python in một số tỷ lệ theo dạng phần (`0–1`) và làm tròn 3 chữ số thập phân; SQL in phần trăm và làm tròn 1 chữ số. Vì vậy, vài nhóm có thể khác 0,1 điểm phần trăm do quy tắc làm tròn ở giá trị đúng giữa hai mức.
- Kiểm định chi-square và phân tích thời điểm tham gia campaign chỉ có trong Python, không phải đầu ra tương ứng của `queries.sql`. Xem chúng như phân tích khám phá; người tham gia campaign có thể tự khác nhóm không tham gia và một số người tham gia sau D7.
- D7 được định nghĩa là có ít nhất một event hoạt động đúng ngày thứ 7 sau ngày đăng ký theo ngày lịch; activation là bắt đầu bài học trong D0–D7.