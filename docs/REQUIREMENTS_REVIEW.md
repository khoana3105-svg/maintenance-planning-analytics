# Đối chiếu yêu cầu và nghiệm thu

Tài liệu điều khiển phạm vi: `../bosch_maintenance_project_requirements_jd_focused.md` ở thư mục cha của dự án. Blueprint `machine_maintenance_project_specification.md` là bản rộng hơn; khi khác nhau, áp dụng bản JD-focused và lựa chọn đã chốt: nhập bằng sheet/nút, không UserForm.

## Phạm vi và bằng chứng

| Yêu cầu JD | Triển khai | Bằng chứng |
|---|---|---|
| 20 máy, 3–4 line, 6 tháng, 500–800 dòng | 20 máy, 4 line, 05–10/2026; 691 dòng nguồn | `data/raw/`, generator seed 42 |
| 3–5% dòng lỗi | 28/691 = 4,05%; 663 hợp lệ | `outputs/run_*/summary.json`, `rejected_records.csv` |
| Tái lập và giữ raw | Generator ghi thư mục mới; không ghi đè raw | Unittest so sánh byte-for-byte |
| Danh mục, lịch sử, lịch PM | 3 nguồn, đúng grain và FK | Data dictionary, SQL schema |
| VBA đơn giản | 3 macro: Validate/Submit, Refresh PM, Export | `excel/Maintenance_Planner.xlsm`, 7 test Excel |
| Nhập/cập nhật | Thêm bằng form sheet, sửa bản ghi trên Table rồi validate | Hướng dẫn VBA |
| Theo dõi PM | Trạng thái, ngày đến hạn/hoàn thành, cảnh báo 7 ngày | Excel và SQL view |
| Python ETL | Đọc/validate/transform/load, ghi batch và quarantine | `src/`, 7 unittest |
| SQL là kho chính | 4 bảng, 3 view; INSERT/UPDATE/SKIP theo ID | Database `MaintenancePlanningJD` |
| Không trùng khi chạy lại | Lần chạy lặp skip đúng 663 dòng | Run log SQL |
| PK/FK/CHECK | Chặn ID trùng, máy không tồn tại, số âm | 3 kiểm tra SQL bằng rollback |
| SQL thực hành | JOIN, GROUP BY, HAVING, CASE, CTE, ROW_NUMBER | `sql/analysis.sql`, `create_views.sql` |
| Power BI ba trang | Overview; Reliability & Failure; PM Performance | PBIX và ảnh trong `powerbi/screenshots/` |
| KPI thống nhất | Downtime, breakdown, MTTR/MTBF, compliance | SQL/Python/DAX đối chiếu 120 máy–tháng, 960 phép kiểm tra |
| Bộ lọc | Tháng, line, máy từ dimensions; quan hệ một-nhiều, hướng đơn | PBIR model/visual definitions và DAX theo máy–tháng |
| M003 lặp sự cố | 142,48 giờ, 30 sự cố Bearing wear | `docs/findings.md` và SQL evidence |
| L01 PM thấp | 40/60 đúng hạn, 66,67%; Corrective tăng theo kỳ | View và findings |
| Ba khuyến nghị có giới hạn | Máy ưu tiên, mode lặp, PM trễ | `docs/findings.md` |
| Không dữ liệu/impact giả thành thật | Nhãn synthetic trên mỗi trang, README và nguồn | Kiểm tra nội dung |

## Định nghĩa cần giữ nhất quán

- Một maintenance record là một hoạt động **đã hoàn thành**. Trong mô phỏng, mọi Corrective là một sự cố hỏng.
- Downtime là giờ dừng không kế hoạch, khác thời gian thực hiện sửa chữa. PM/Inspection có downtime không kế hoạch bằng 0.
- MTTR/MTBF có mẫu số 0 trả BLANK/NULL; tổng được tính lại từ tử/mẫu, không trung bình tỷ lệ của các máy.
- Lịch giả định: 16 giờ/ngày, 26 ngày/tháng, 2.496 giờ/máy trong sáu tháng. Ngày 1–26 mang 16 giờ, ngày còn lại 0 khi lọc kỳ lẻ.
- PM compliance theo **Due_Date** trong kỳ lọc; loại Cancelled; hoàn thành muộn không tính đúng hạn. Snapshot cố định 31/10/2026.
- Ngày snapshot Excel/SQL/Power BI cần đổi cùng nhau nếu chuyển kỳ mô phỏng.

## Các khác biệt có chủ đích và giới hạn

1. **Ba CSV thay vì năm:** Failure_Mode và Downtime_Hours nằm ngay trong maintenance record, tránh ghép suy đoán hai fact theo mã máy. Bản cũ có downtime interval được giữ trong archive.
2. **Không có Start/End:** ví dụ kiểm tra “End trước Start” trong JD không thể áp dụng cho schema tổng giờ. Phiên bản này kiểm tra downtime không âm; không tuyên bố đã kiểm tra chồng lấn từ tổng giờ.
3. **PM Daily/Weekly/Monthly là nhiệm vụ lấy mẫu:** không sinh mọi ngày/tuần của nhà máy và không tự tạo nhiệm vụ kỳ tiếp theo. Chưa tối ưu nguồn lực, phụ tùng hoặc lịch theo ràng buộc.
4. **Theo dõi trạng thái đơn giản:** sửa status trên Excel và upsert theo ID; chưa có lịch sử trạng thái work order, SAP PM hay CMMS.
5. **Snapshot lịch sử:** slicer tháng chọn cohort theo due date; không tái dựng trạng thái “đã biết tại cuối từng tháng”.
6. **Kịch bản cố ý cài:** M003 và L01 là mô phỏng để luyện phân tích, không xác lập nguyên nhân cơ khí hoặc nhân quả PM → downtime.
7. **Bằng chứng kiểm thử:** 7 VBA tests thuộc bản JD; 36 tests cũ thuộc bản năm nguồn, không dùng thay cho nghiệm thu phiên bản này.

Các giới hạn này cần được giữ trong README/CV/phỏng vấn. Không tuyên bố giảm downtime, tiết kiệm chi phí hay triển khai tại Bosch từ dự án mô phỏng.
