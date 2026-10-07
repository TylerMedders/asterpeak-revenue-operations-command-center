# Clean Data Note

The original synthetic CRM dataset is preserved unchanged in `02_Raw_Data`.

This project does not maintain a separate materialized clean-data export. Data-quality rules, expected segmentation and ownership logic, pipeline classifications, routing audits, forecast checks, and Deal Desk governance analysis are implemented through the SQL analysis, Excel audit workbook, and Power BI model.

This approach preserves the original source data while keeping transformation and audit logic transparent and reproducible.