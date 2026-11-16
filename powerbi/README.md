# Sử dụng báo cáo Power BI

**File mở chính:** `Maintenance_Analytics.pbix`. Ba trang đã được dựng, nạp SQL và đối chiếu DAX. PBIP và hai thư mục Report/SemanticModel là bản mã nguồn chỉnh sửa; không xóa một phần trong hai thư mục này.

## Cách xem

1. Mở PBIX bằng Power BI Desktop.
2. Chọn trang ở thanh dưới. Slicers phía trên lọc tháng, line và máy; có thể chọn nhiều giá trị.
3. Bấm lại giá trị đã chọn hoặc Clear selections để trở về All.
4. Scroll trong chart/table khi có nhiều máy/nhiệm vụ.

PM snapshot cố định **31/10/2026**. Due Soon = 0 là kết quả hợp lệ của bộ dữ liệu này, không phải lỗi báo cáo. MTBF là ước lượng theo lịch mô phỏng ghi ngay trên trang Overview.

## Refresh sau khi nhập Excel

```text
Excel: Validate/Submit → Export three CSVs
Python: python -m src.main --source exports/<batch>
Power BI: Home → Refresh → chờ hoàn tất → Ctrl+S
```

Nguồn: SQL Server `localhost`, database `MaintenancePlanningJD`, Windows Authentication. Power Query đọc trực tiếp `Dim_Machine`, `vw_Breakdown_Analysis`, `vw_PM_Performance`; Dim_Date được tạo trong M. Không dùng `outputs/*.csv` làm nguồn báo cáo. View `vw_Machine_Downtime` dùng đối chiếu SQL theo máy-tháng.

Đã dùng SELECT chỉ đọc với `CreateNavigationProperties=false` để giảm truy vấn metadata khi refresh. Khi chuyển máy, chọn lại Windows credentials và xác minh/chấp thuận các native SELECT của project nếu Power BI hỏi. Không cài gateway hoặc publish cloud trong phiên bản local này.

## Model và kiểm chứng

- Dim_Machine lọc hai fact theo Machine_ID.
- Dim_Date lọc maintenance theo Event_Day và PM theo Due_Date.
- Quan hệ một-nhiều, hướng đơn; không nối hai fact trực tiếp.
- 11 measures; count không có nhiệm vụ trả 0, MTTR/MTBF mẫu số 0 trả BLANK.
- Không dùng trung bình MTBF/MTTR từng máy cho tổng.
- 120 máy–tháng × 8 chỉ tiêu = 960 đối chiếu độc lập với Python, cùng kiểm tra zero-failure và mở lại file.
- Bằng chứng: `../tests/powerbi_reconciliation.json`, `powerbi_saved_reopen.json`, `powerbi_edges.json`, ảnh `screenshots/`.

Toàn kỳ: downtime 507,95; breakdown 168; MTTR 2,4485119; planned hours 49.920; MTBF 294,1193452; compliance 220/240 = 91,6667%; overdue 5; due soon 0.

## Chỉnh sửa và tái lập

`Maintenance_Analytics.pbip` mở source project. `Measures.dax` là tài liệu công thức; `FinalizeMeasures.dax` dùng DAX query view để áp dụng định nghĩa qua UI khi cần. Các script build/polish là công cụ tác giả, không chạy chúng sau khi tự sửa report nếu chưa sao lưu: chúng có thể ghi đè cấu hình nguồn. Cách dùng thông thường chỉ cần PBIX, Excel và ETL.

Định dạng source theo tài liệu Microsoft: [PBIP](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview), [PBIR](https://learn.microsoft.com/en-us/power-bi/developer/embedded/projects-enhanced-report-format), [semantic model](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset).
