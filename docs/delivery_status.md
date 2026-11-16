# Trạng thái bàn giao

Phiên bản JD-focused: Excel/VBA, Python, SQL và Power BI local đã có đầu ra. Mở `powerbi/Maintenance_Analytics.pbix` để xem báo cáo; mở `excel/Maintenance_Planner.xlsm` để nhập liệu.

Chi tiết đối chiếu từng yêu cầu, khác biệt có chủ đích và giới hạn: [REQUIREMENTS_REVIEW.md](REQUIREMENTS_REVIEW.md).

## Bằng chứng chính

- 7 bài kiểm thử Python và 7 kiểm thử VBA JD đạt.
- 3 kiểm tra ràng buộc SQL đạt; SQL rerun skip 663 dòng, không tạo bản ghi trùng.
- Model Power BI: 20 máy, 403 hoạt động, 240 PM, 184 ngày.
- 120 máy–tháng, 960 đối chiếu KPI DAX/Python đạt; MTTR/MTBF không có sự cố trả BLANK.
- PBIX đã lưu và mở lại; count Due Soon = 0 được giữ sau khi lưu.
- Kiểm thử slicer M003: PM compliance 66,67%; bỏ lọc về 91,67%.
- Một fixture CSV dựa trên bản xuất Excel được nạp SQL và quan sát trong model: 403 → 404. Chỉ fixture đó bị xóa khi dọn thử nghiệm; baseline SQL và báo cáo được xác nhận về 403.
- Các ảnh ba trang nằm trong `powerbi/screenshots/`; kết quả DAX và kiểm chứng ở `tests/`.

Chưa triển khai các phần ngoài scope: CMMS đầy đủ, SAP, sensor, ML, cloud, tối ưu lịch theo công suất và lịch PM dày cho mọi ngày/tuần. PM là snapshot cố định, không có lịch sử trạng thái theo thời điểm. Không tuyên bố tác động kinh doanh thực từ dữ liệu mô phỏng.
