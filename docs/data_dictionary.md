# Data dictionary

Schema nguồn chuẩn nằm trong `src/config.py` (FILES), ràng buộc DB trong `sql/create_tables.sql`.

- machines.csv: Machine_ID (khóa), Machine_Name (tên giả), Line_ID (L01–L04), Criticality (High/Medium/Low).
- maintenance_records.csv: Maintenance_ID (khóa), Machine_ID (FK), Date (ngày/giờ sự kiện), Type (Preventive/Corrective/Inspection), Failure_Mode (bắt buộc với Corrective), Duration_Hours (giờ công việc), Downtime_Hours (giờ ngừng máy không kế hoạch; chỉ Corrective có thể >0), Status (Completed).
- pm_schedule.csv: PM_ID (khóa), Machine_ID (FK), PM_Type (loại nhiệm vụ), Due_Date (ngày đến hạn trong kỳ), Completed_Date (chỉ có khi Completed và không sau cutoff), Status (Planned/Completed/Cancelled).
- ETL_Run_Log: batch, UTC bắt đầu/kết thúc, số đọc/chấp nhận/cách ly/thêm/cập nhật/bỏ qua, trạng thái/lỗi.

Null: Failure_Mode được phép rỗng ở hoạt động không Corrective. Completed_Date rỗng khi Planned/Cancelled. Các trường còn lại bắt buộc. Các cột số phải hữu hạn và không âm. Ngày nguồn ISO; ID dạng chuỗi, giữ số 0 đầu.

Excel thêm hai cột dẫn xuất ở PM: Alert_Status và Days_Remaining, không xuất sang CSV. Chi phí, kỹ thuật viên và kho vật tư ngoài scope JD tối giản. Các trường cũ được giữ trong archive, không chuyển đổi suy đoán sang schema mới.
