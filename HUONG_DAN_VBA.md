# Dùng Excel/VBA

Mở **excel/Maintenance_Planner.xlsm** bằng Excel Desktop. Mã VBA đã được nạp; không cần tự import hoặc bật quyền truy cập VBA Project. Chỉ cho phép macro của workbook bạn tin cậy.

## 1. Nhập một hoạt động

Trong Dashboard_Menu, điền form:

| Ô | Ý nghĩa | Ví dụ mô phỏng |
|---|---|---|
| B8 | Maintenance_ID, có thể để trống để tự sinh | trống |
| B9 | Machine_ID | M001 |
| B10 | Ngày/giờ trong kỳ 05–10/2026 | 15/10/2026 |
| B11 | Type | Inspection |
| B12 | Failure_Mode, bắt buộc với Corrective | trống cho Inspection |
| B13 | Duration_Hours ≥ 0 | 1 |
| B14 | Downtime_Hours không kế hoạch ≥ 0 | 0 |
| B15 | Status | Completed |

Bấm **Validate / Submit**. Thành công: thêm một dòng rồi xóa form. Sai: giữ form để sửa, không thêm dòng. Khi form trống, nút chỉ kiểm tra các bảng. Muốn sửa hoạt động cũ, sửa trực tiếp đúng dòng trong Table rồi validate; không tạo bản ghi cùng ID.

Không đổi tên/thứ tự cột, sheet hoặc Table. ID phải duy nhất, mã máy tồn tại, số nhập là giá trị số, loại bảo trì hợp lệ. Corrective bắt buộc Failure_Mode; hoạt động không Corrective phải có downtime không kế hoạch bằng 0. Phiên bản này chỉ lưu hoạt động đã hoàn thành.

## 2. Theo dõi PM

Nhập/sửa trực tiếp trong PM_Schedule. Completed cần Completed_Date; Planned/Cancelled để trống ngày hoàn thành. Không nhập tay hai cột kết quả cuối.

Dashboard_Menu!B18 là ngày snapshot, mặc định 31/10/2026. Bấm **Refresh PM Status**:

- Completed/Cancelled giữ trạng thái.
- Đến hạn trước snapshot → Overdue.
- Đến hạn từ snapshot đến 7 ngày tiếp theo → Due Soon.
- Xa hơn → Upcoming.

Các nhiệm vụ trong bản hiện tại thuộc kỳ 05–10/2026. Daily/Weekly/Monthly là loại nhiệm vụ lấy mẫu, chưa tự sinh lịch kỳ sau. Muốn mở rộng kỳ, đổi policy Python/SQL/Excel/Power BI cùng nhau.

## 3. Xuất và cập nhật báo cáo

Bấm **Export three CSVs**. Macro kiểm tra rồi tạo `exports/<batch>/` với machines.csv, maintenance_records.csv và pm_schedule.csv, UTF-8 BOM. Xuất cả dòng đang bị bộ lọc ẩn, không xuất cột cảnh báo PM, không ghi đè batch cũ. Không nạp thư mục `.partial` nếu có lỗi giữa chừng.

Export_Log ghi thời gian, file, số dòng và đường dẫn khi thành công. Kết quả/lỗi hiện ở B3 và hộp thoại. Nhấn Ctrl+S để lưu workbook và log.

```powershell
# Chạy từ thư mục Maintenance
python -m src.main --source exports/<batch>
```

Sau đó mở Power BI và chọn Home → Refresh, chờ hoàn tất rồi Ctrl+S.

Nguồn ban đầu: 20 máy, 403 hoạt động, 240 nhiệm vụ PM. Năm sheet: Dashboard_Menu, Machine_Master, Maintenance_Input, PM_Schedule, Export_Log. Downtime và Failure_Mode nằm trong hoạt động; file cũ có sheet riêng được giữ trong archive.

Code đang dùng: `vba/JDPlanner.bas`. Bộ 7 kiểm thử VBA của bản JD nằm trong `tests/excel_results.json`; test chạy trên bản sao, không chạy bộ phá/sửa dữ liệu thử trên workbook nhập liệu chính.
