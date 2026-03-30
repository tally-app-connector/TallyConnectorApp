# Project Structure Consolidation - Change Log

**Date:** 2026-03-28
**Purpose:** Consolidate duplicate folders (models, services, utils, widgets, config) scattered across `lib/screens/`, `lib/ai/`, and `lib/` into single top-level folders under `lib/`.

---

## Summary

| Action | Count |
|--------|-------|
| Files Moved | 36 |
| Files Deleted | 2 |
| Files With Import Updates | 54 |
| Old Folders Removed | 10 |

---

## 1. Files Moved (Old Path → New Path)

### Models (3 folders → 1 folder `lib/models/`)

| # | Old Path | New Path |
|---|----------|----------|
| 1 | `lib/screens/models/company_model.dart` | `lib/models/company_model.dart` |
| 2 | `lib/screens/models/kpi_metric.dart` | `lib/models/kpi_metric.dart` |
| 3 | `lib/screens/models/report_data.dart` | `lib/models/report_data.dart` |
| 4 | `lib/screens/models/sales_data.dart` | `lib/models/sales_data.dart` |
| 5 | `lib/ai/models/chat_message.dart` | `lib/models/ai/chat_message.dart` |
| 6 | `lib/ai/models/metric_config.dart` | `lib/models/ai/metric_config.dart` |
| 7 | `lib/ai/models/query_result.dart` | `lib/models/ai/query_result.dart` |
| 8 | `lib/ai/models/query_template.dart` | `lib/models/ai/query_template.dart` |

### Services (3 folders → 1 folder `lib/services/`)

| # | Old Path | New Path |
|---|----------|----------|
| 9 | `lib/screens/service/company_logo_service.dart` | `lib/services/company_logo_service.dart` |
| 10 | `lib/screens/service/data_sync_service.dart` | `lib/services/data_sync_service.dart` |
| 11 | `lib/screens/service/excel_export_service.dart` | `lib/services/excel_export_service.dart` |
| 12 | `lib/screens/service/pdf_export_service.dart` | `lib/services/pdf_export_service.dart` |
| 13 | `lib/screens/service/xml_export_service.dart` | `lib/services/xml_export_service.dart` |
| 14 | `lib/screens/service/sales/sales_service.dart` | `lib/services/sales_service.dart` |
| 15 | `lib/ai/services/ai_provider_service.dart` | `lib/services/ai/ai_provider_service.dart` |
| 16 | `lib/ai/services/ai_qa_service.dart` | `lib/services/ai/ai_qa_service.dart` |
| 17 | `lib/ai/services/claude_service.dart` | `lib/services/ai/claude_service.dart` |
| 18 | `lib/ai/services/entity_extractor.dart` | `lib/services/ai/entity_extractor.dart` |
| 19 | `lib/ai/services/prompt_builder.dart` | `lib/services/ai/prompt_builder.dart` |
| 20 | `lib/ai/services/query_builder.dart` | `lib/services/ai/query_builder.dart` |
| 21 | `lib/ai/services/query_templates.dart` | `lib/services/ai/query_templates.dart` |
| 22 | `lib/ai/services/schema_provider.dart` | `lib/services/ai/schema_provider.dart` |
| 23 | `lib/ai/services/template_matcher.dart` | `lib/services/ai/template_matcher.dart` |

### Utils (2 folders → 1 folder `lib/utils/`)

| # | Old Path | New Path |
|---|----------|----------|
| 24 | `lib/screens/utils/amount_formatter.dart` | `lib/utils/amount_formatter.dart` |
| 25 | `lib/screens/utils/chart_period_helper.dart` | `lib/utils/chart_period_helper.dart` |

### Widgets (2 folders → 1 folder `lib/widgets/`)

| # | Old Path | New Path |
|---|----------|----------|
| 26 | `lib/screens/widgets/dashboard_widgets.dart` | `lib/widgets/dashboard_widgets.dart` |
| 27 | `lib/screens/widgets/detail_widgets.dart` | `lib/widgets/detail_widgets.dart` |
| 28 | `lib/screens/widgets/kpi_widgets.dart` | `lib/widgets/kpi_widgets.dart` |
| 29 | `lib/screens/widgets/report_overview_widgets.dart` | `lib/widgets/report_overview_widgets.dart` |
| 30 | `lib/screens/widgets/report_widgets.dart` | `lib/widgets/report_widgets.dart` |
| 31 | `lib/screens/widgets/charts/report_chart.dart` | `lib/widgets/charts/report_chart.dart` |
| 32 | `lib/screens/widgets/charts/sales_bar_chart.dart` | `lib/widgets/charts/sales_bar_chart.dart` |
| 33 | `lib/screens/widgets/charts/sales_purchase_combo_chart.dart` | `lib/widgets/charts/sales_purchase_combo_chart.dart` |

### Config (2 folders → 1 folder `lib/config/`)

| # | Old Path | New Path |
|---|----------|----------|
| 34 | `lib/ai/config/ai_endpoints.dart` | `lib/config/ai_endpoints.dart` |

### AI Dependencies (moved to `lib/config/`)

| # | Old Path | New Path |
|---|----------|----------|
| 35 | `lib/ai/di/ai_dependencies.dart` | `lib/config/ai_dependencies.dart` |

---

## 2. Files Deleted

| # | File Path | Reason |
|---|-----------|--------|
| 1 | `lib/screens/utils/secure_storage.dart` | Was only a re-export of `lib/utils/secure_storage.dart`. No longer needed after consolidation. |
| 2 | `lib/screens/widgets/charts/sales_purchase_combo_chart.dart` | Was only a re-export of `report_chart.dart show SalesPurchaseComboChart`. After move, imports point directly to `lib/widgets/charts/report_chart.dart`. |

---

## 3. Old Folders Removed (Empty After Moves)

| # | Folder Path |
|---|-------------|
| 1 | `lib/screens/models/` |
| 2 | `lib/screens/service/sales/` |
| 3 | `lib/screens/service/` |
| 4 | `lib/screens/utils/` |
| 5 | `lib/screens/widgets/charts/` |
| 6 | `lib/screens/widgets/` |
| 7 | `lib/ai/models/` |
| 8 | `lib/ai/services/` |
| 9 | `lib/ai/config/` |
| 10 | `lib/ai/di/` |

> **Note:** After all moves, the `lib/ai/` folder becomes completely empty and is also removed.

---

## 4. Import Changes Per File

Below is every file where import statements were changed, showing the exact old → new import line.

---

### `lib/screens/main.dart`

| Old Import | New Import |
|------------|------------|
| `import 'models/company_model.dart';` | `import '../models/company_model.dart';` |

---

### `lib/screens/home/ai_queries_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../../ai/services/ai_provider_service.dart';` | `import '../../services/ai/ai_provider_service.dart';` |
| `import '../../ai/models/metric_config.dart';` | `import '../../models/ai/metric_config.dart';` |
| `import '../../ai/services/ai_qa_service.dart';` | `import '../../services/ai/ai_qa_service.dart';` |
| `import '../../ai/models/query_result.dart';` | `import '../../models/ai/query_result.dart';` |
| `import '../../ai/services/query_templates.dart';` | `import '../../services/ai/query_templates.dart';` |
| `import '../../ai/services/query_builder.dart';` | `import '../../services/ai/query_builder.dart';` |

---

### `lib/screens/mobile/dashboard_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../widgets/dashboard_widgets.dart';` | `import '../../widgets/dashboard_widgets.dart';` |
| `import '../models/kpi_metric.dart';` | `import '../../models/kpi_metric.dart';` |
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../utils/secure_storage.dart';` | `import '../../utils/secure_storage.dart';` |
| `import '../models/company_model.dart';` | `import '../../models/company_model.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |
| `import '../utils/chart_period_helper.dart';` | `import '../../utils/chart_period_helper.dart';` |

---

### `lib/screens/mobile/reports_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../widgets/report_widgets.dart';` | `import '../../widgets/report_widgets.dart';` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |
| `import '../models/company_model.dart';` | `import '../../models/company_model.dart';` |
| `import '../utils/secure_storage.dart';` | `import '../../utils/secure_storage.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |
| `import '../widgets/charts/sales_purchase_combo_chart.dart';` | `import '../../widgets/charts/sales_purchase_combo_chart.dart';` |
| `import '../widgets/charts/report_chart.dart' hide SalesPurchaseComboChart;` | `import '../../widgets/charts/report_chart.dart' hide SalesPurchaseComboChart;` |

---

### `lib/screens/mobile/metric_detail_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../models/company_model.dart';` | `import '../../models/company_model.dart';` |
| `import '../widgets/report_widgets.dart';` | `import '../../widgets/report_widgets.dart';` |
| `import '../widgets/charts/sales_purchase_combo_chart.dart';` | `import '../../widgets/charts/sales_purchase_combo_chart.dart';` |
| `import '../widgets/charts/report_chart.dart' hide SalesPurchaseComboChart;` | `import '../../widgets/charts/report_chart.dart' hide SalesPurchaseComboChart;` |
| `import '../models/sales_data.dart' hide ChartPeriod;` | `import '../../models/sales_data.dart' hide ChartPeriod;` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |
| `import '../utils/chart_period_helper.dart';` | `import '../../utils/chart_period_helper.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

---

### `lib/screens/mobile/outstanding_detail_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../widgets/charts/report_chart.dart';` | `import '../../widgets/charts/report_chart.dart';` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

---

### `lib/screens/mobile/net_sales_detail_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../widgets/dashboard_widgets.dart';` | `import '../../widgets/dashboard_widgets.dart';` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |
| `import '../widgets/charts/sales_bar_chart.dart';` | `import '../../widgets/charts/sales_bar_chart.dart';` |
| `import '../models/sales_data.dart';` | `import '../../models/sales_data.dart';` |
| `import '../models/report_data.dart' hide ChartPeriod;` | `import '../../models/report_data.dart' hide ChartPeriod;` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

---

### `lib/screens/mobile/kpi_manager_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/kpi_metric.dart';` | `import '../../models/kpi_metric.dart';` |
| `import '../widgets/kpi_widgets.dart';` | `import '../../widgets/kpi_widgets.dart';` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |

---

### `lib/screens/mobile/excel_export_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

---

### `lib/screens/mobile/group_outstanding_detail_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

---

### `lib/screens/mobile/reports_overview_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../widgets/report_overview_widgets.dart';` | `import '../../widgets/report_overview_widgets.dart';` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |

---

### `lib/screens/mobile/pdf_export_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../models/company_model.dart';` | `import '../../models/company_model.dart';` |
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |

---

### `lib/screens/mobile/Recevaible_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |

---

### `lib/screens/mobile/mobile_dashboard_tab.dart`

| Old Import | New Import |
|------------|------------|
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

---

### `lib/screens/widgets/report_widgets.dart` (now at `lib/widgets/report_widgets.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../models/report_data.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../utils/amount_formatter.dart';` |

> No change needed — relative paths remain the same after all files move up one level together.

---

### `lib/screens/widgets/kpi_widgets.dart` (now at `lib/widgets/kpi_widgets.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/kpi_metric.dart';` | `import '../models/kpi_metric.dart';` |

> No change needed — relative path stays the same.

---

### `lib/screens/widgets/dashboard_widgets.dart` (now at `lib/widgets/dashboard_widgets.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/kpi_metric.dart';` | `import '../models/kpi_metric.dart';` |

> No change needed — relative path stays the same.

---

### `lib/screens/widgets/detail_widgets.dart` (now at `lib/widgets/detail_widgets.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../models/report_data.dart';` |

> No change needed — relative path stays the same.

---

### `lib/screens/widgets/charts/report_chart.dart` (now at `lib/widgets/charts/report_chart.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |
| `import '../../utils/chart_period_helper.dart';` | `import '../../utils/chart_period_helper.dart';` |

> No change needed — relative paths stay the same.

---

### `lib/screens/widgets/charts/sales_bar_chart.dart` (now at `lib/widgets/charts/sales_bar_chart.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../../models/sales_data.dart';` | `import '../../models/sales_data.dart';` |
| `import '../../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

> No change needed — relative paths stay the same.

---

### `lib/screens/utils/chart_period_helper.dart` (now at `lib/utils/chart_period_helper.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../models/report_data.dart';` |

> No change needed — relative path stays the same.

---

### `lib/screens/service/excel_export_service.dart` (now at `lib/services/excel_export_service.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../models/report_data.dart';` |
| `import '../../database/database_helper.dart';` | `import '../database/database_helper.dart';` |

---

### `lib/screens/service/data_sync_service.dart` (now at `lib/services/data_sync_service.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../../services/cloud_to_local_sync_service.dart';` | `import 'cloud_to_local_sync_service.dart';` |
| `import '../../database/database_helper.dart';` | `import '../database/database_helper.dart';` |

---

### `lib/screens/service/pdf_export_service.dart` (now at `lib/services/pdf_export_service.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../models/report_data.dart';` |
| `import '../models/company_model.dart';` | `import '../models/company_model.dart';` |

> No change needed — relative paths stay the same.

---

### `lib/screens/service/xml_export_service.dart` (now at `lib/services/xml_export_service.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../models/report_data.dart';` |

> No change needed — relative path stays the same.

---

### `lib/screens/service/sales/sales_service.dart` (now at `lib/services/sales_service.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../../models/report_data.dart';` | `import '../models/report_data.dart';` |
| `import '../../utils/amount_formatter.dart';` | `import '../utils/amount_formatter.dart';` |
| `import '../../../database/database_helper.dart';` | `import '../database/database_helper.dart';` |

---

### `lib/ai/services/ai_qa_service.dart` (now at `lib/services/ai/ai_qa_service.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../../database/database_helper.dart';` | `import '../../database/database_helper.dart';` |
| `import '../models/chat_message.dart';` | `import '../../models/ai/chat_message.dart';` |
| `import '../models/query_result.dart';` | `import '../../models/ai/query_result.dart';` |
| `import '../config/ai_endpoints.dart';` | `import '../../config/ai_endpoints.dart';` |
| `import '../services/prompt_builder.dart';` | `import 'prompt_builder.dart';` |
| `import '../services/entity_extractor.dart';` | `import 'entity_extractor.dart';` |
| `import '../services/claude_service.dart';` | `import 'claude_service.dart';` |
| `import '../services/ai_provider_service.dart';` | `import 'ai_provider_service.dart';` |
| `import '../services/query_templates.dart';` | `import 'query_templates.dart';` |
| `import '../services/query_builder.dart';` | `import 'query_builder.dart';` |
| `import '../services/template_matcher.dart';` | `import 'template_matcher.dart';` |

---

### `lib/ai/services/template_matcher.dart` (now at `lib/services/ai/template_matcher.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/query_template.dart';` | `import '../../models/ai/query_template.dart';` |

---

### `lib/ai/services/query_templates.dart` (now at `lib/services/ai/query_templates.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/query_template.dart';` | `import '../../models/ai/query_template.dart';` |

---

### `lib/ai/services/query_builder.dart` (now at `lib/services/ai/query_builder.dart`)

| Old Import | New Import |
|------------|------------|
| `import '../models/query_template.dart';` | `import '../../models/ai/query_template.dart';` |

---

### `lib/ai/services/prompt_builder.dart` (now at `lib/services/ai/prompt_builder.dart`)

| Old Import | New Import |
|------------|------------|
| `import 'schema_provider.dart';` | `import 'schema_provider.dart';` |

> No change needed — sibling import stays the same.

---

## 5. Additional Import Changes (Discovered During Verification)

These files had imports not caught in the initial scan (duplicate code blocks, theme/icons/di references).

---

### `lib/main.dart`

| Old Import | New Import |
|------------|------------|
| `import 'screens/models/company_model.dart';` | `import 'models/company_model.dart';` |
| `import 'ai/di/ai_dependencies.dart';` | `import 'config/ai_dependencies.dart';` |
| `import './ai/config/ai_endpoints.dart';` | `import 'config/ai_endpoints.dart';` |

---

### `lib/models/kpi_metric.dart`

| Old Import | New Import |
|------------|------------|
| `import '../theme/app_theme.dart';` | `import '../screens/theme/app_theme.dart';` |
| `import '../icons/app_icons.dart';` | `import '../screens/icons/app_icons.dart';` |

---

### `lib/models/report_data.dart`

| Old Import | New Import |
|------------|------------|
| `import '../theme/app_theme.dart';` | `import '../screens/theme/app_theme.dart';` |
| `import '../icons/app_icons.dart';` | `import '../screens/icons/app_icons.dart';` |

---

### `lib/screens/home/ai_queries_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../../ai/di/ai_dependencies.dart';` | `import '../../config/ai_dependencies.dart';` |

---

### `lib/services/ai/ai_qa_service.dart`

| Old Import | New Import |
|------------|------------|
| `import '../di/ai_dependencies.dart';` | `import '../../config/ai_dependencies.dart';` |

---

### `lib/widgets/report_widgets.dart`

| Old Import | New Import |
|------------|------------|
| `import '../theme/app_theme.dart';` | `import '../screens/theme/app_theme.dart';` |

---

### `lib/widgets/report_overview_widgets.dart`

| Old Import | New Import |
|------------|------------|
| `import '../theme/app_theme.dart';` | `import '../screens/theme/app_theme.dart';` |

---

### `lib/widgets/kpi_widgets.dart`

| Old Import | New Import |
|------------|------------|
| `import '../theme/app_theme.dart';` | `import '../screens/theme/app_theme.dart';` |

---

### `lib/widgets/detail_widgets.dart`

| Old Import | New Import |
|------------|------------|
| `import '../theme/app_theme.dart';` | `import '../screens/theme/app_theme.dart';` |

---

### `lib/widgets/dashboard_widgets.dart`

| Old Import | New Import |
|------------|------------|
| `import '../theme/app_theme.dart';` | `import '../screens/theme/app_theme.dart';` |

---

### `lib/widgets/charts/report_chart.dart`

| Old Import | New Import |
|------------|------------|
| `import '../../theme/app_theme.dart';` | `import '../../screens/theme/app_theme.dart';` |

---

### `lib/widgets/charts/sales_bar_chart.dart`

| Old Import | New Import |
|------------|------------|
| `import '../../theme/app_theme.dart';` | `import '../../screens/theme/app_theme.dart';` |

---

### `lib/screens/mobile/dashboard_screen.dart` (second code block ~line 970)

| Old Import | New Import |
|------------|------------|
| `import '../widgets/dashboard_widgets.dart';` | `import '../../widgets/dashboard_widgets.dart';` |
| `import '../models/kpi_metric.dart';` | `import '../../models/kpi_metric.dart';` |
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |
| `import '../service/data_sync_service.dart';` | `import '../../services/data_sync_service.dart';` |
| `import '../utils/secure_storage.dart';` | `import '../../utils/secure_storage.dart';` |
| `import '../models/company_model.dart';` | `import '../../models/company_model.dart';` |

---

### `lib/screens/mobile/Recevaible_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |

---

### `lib/screens/mobile/group_outstanding_detail_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |

---

### `lib/screens/mobile/excel_export_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../service/pdf_export_service.dart';` | `import '../../services/pdf_export_service.dart';` |
| `import '../service/xml_export_service.dart';` | `import '../../services/xml_export_service.dart';` |

---

### `lib/screens/mobile/net_sales_detail_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |

---

### `lib/screens/mobile/metric_detail_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |
| `import '../service/company_logo_service.dart';` | `import '../../services/company_logo_service.dart';` |
| `import '../service/excel_export_service.dart';` | `import '../../services/excel_export_service.dart';` |

---

### `lib/screens/mobile/pdf_export_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../service/pdf_export_service.dart';` | `import '../../services/pdf_export_service.dart';` |

---

### `lib/screens/mobile/reports_screen.dart`

| Old Import | New Import |
|------------|------------|
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |
| `import '../service/company_logo_service.dart';` | `import '../../services/company_logo_service.dart';` |
| `import '../service/excel_export_service.dart';` | `import '../../services/excel_export_service.dart';` |

---

### `lib/screens/mobile/outstanding_detail_screen.dart` (second code block ~line 2148)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../widgets/charts/report_chart.dart';` | `import '../../widgets/charts/report_chart.dart';` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |
| `import '../utils/amount_formatter.dart';` | `import '../../utils/amount_formatter.dart';` |

---

### `lib/screens/mobile/reports_overview_screen.dart` (second code block ~line 203)

| Old Import | New Import |
|------------|------------|
| `import '../models/report_data.dart';` | `import '../../models/report_data.dart';` |
| `import '../widgets/report_overview_widgets.dart';` | `import '../../widgets/report_overview_widgets.dart';` |
| `import '../widgets/detail_widgets.dart';` | `import '../../widgets/detail_widgets.dart';` |
| `import '../service/sales/sales_service.dart';` | `import '../../services/sales_service.dart';` |

---

## 6. Files With NO Import Changes Required

These files were either moved but their relative imports stayed the same, or they were not moved and their imports already point to `lib/`-level folders:

- `lib/screens/Analysis/*.dart` — all import from `../../database/`, `../../models/`, `../../utils/` which already resolve to `lib/` level. **No changes.**
- `lib/screens/auth/*.dart` — all import from `../../services/`, `../../utils/`, `../../widgets/` which already resolve to `lib/` level. **No changes.**
- `lib/screens/desktop/*.dart` — imports from `../../database/`, `../../utils/`, `package:tally_connector/services/` — **No changes.**
- `lib/screens/home/home_screen.dart` — imports from `../../services/`, `../../utils/`, `../../models/` — **No changes.**
- `lib/screens/sync_screen.dart` — imports from `../database/`, `../services/`, `../utils/`, `../models/` — **No changes.**
- `lib/database/database_helper.dart` — imports from `../models/`, `../services/`, `../utils/` — **No changes.**
- `lib/services/*.dart` — imports from `../models/`, `../config/`, `../database/`, `../utils/`, `package:tally_connector/` — **No changes.**
- `lib/screens/mobile/mobile_home_screen.dart` — imports only from `../theme/` and sibling files — **No changes.**
- `lib/screens/mobile/mobile_reports_tab.dart` — imports only from `../theme/` and `../Analysis/` — **No changes.**
- `lib/screens/mobile/mobile_profile_tab.dart` — imports from `../../services/`, `../../database/`, `../../utils/`, `../../models/` — **No changes.**
- `lib/ai/services/ai_provider_service.dart` — no local project imports — **No changes.**
- `lib/ai/services/claude_service.dart` — no local project imports — **No changes.**
- `lib/ai/services/entity_extractor.dart` — no local project imports — **No changes.**
- `lib/ai/services/schema_provider.dart` — no local project imports — **No changes.**
- `lib/ai/di/ai_dependencies.dart` (now `lib/config/ai_dependencies.dart`) — only imports `package:sqflite` — **No changes.**

---

## 6. New Folder Structure After Consolidation

```
lib/
├── main.dart
├── config/
│   ├── api_config.dart
│   ├── ai_endpoints.dart          ← moved from ai/config/
│   └── ai_dependencies.dart       ← moved from ai/di/
├── database/
│   └── database_helper.dart
├── models/
│   ├── data_model.dart
│   ├── user_model.dart
│   ├── company_model.dart         ← moved from screens/models/
│   ├── kpi_metric.dart            ← moved from screens/models/
│   ├── report_data.dart           ← moved from screens/models/
│   ├── sales_data.dart            ← moved from screens/models/
│   └── ai/
│       ├── chat_message.dart      ← moved from ai/models/
│       ├── metric_config.dart     ← moved from ai/models/
│       ├── query_result.dart      ← moved from ai/models/
│       └── query_template.dart    ← moved from ai/models/
├── services/
│   ├── analytics_service.dart
│   ├── auth_service.dart
│   ├── aws_sync_service.dart
│   ├── cloud_to_local_sync_service.dart
│   ├── cognito_service.dart
│   ├── neon_sync_service.dart
│   ├── sync_service.dart
│   ├── tally_service.dart
│   ├── tally_xml_parser.dart
│   ├── company_logo_service.dart  ← moved from screens/service/
│   ├── data_sync_service.dart     ← moved from screens/service/
│   ├── excel_export_service.dart  ← moved from screens/service/
│   ├── pdf_export_service.dart    ← moved from screens/service/
│   ├── xml_export_service.dart    ← moved from screens/service/
│   ├── sales_service.dart         ← moved from screens/service/sales/
│   └── ai/
│       ├── ai_provider_service.dart  ← moved from ai/services/
│       ├── ai_qa_service.dart        ← moved from ai/services/
│       ├── claude_service.dart       ← moved from ai/services/
│       ├── entity_extractor.dart     ← moved from ai/services/
│       ├── prompt_builder.dart       ← moved from ai/services/
│       ├── query_builder.dart        ← moved from ai/services/
│       ├── query_templates.dart      ← moved from ai/services/
│       ├── schema_provider.dart      ← moved from ai/services/
│       └── template_matcher.dart     ← moved from ai/services/
├── utils/
│   ├── date_utils.dart
│   ├── message_helper.dart
│   ├── secure_storage.dart
│   ├── validators.dart
│   ├── amount_formatter.dart      ← moved from screens/utils/
│   └── chart_period_helper.dart   ← moved from screens/utils/
├── widgets/
│   ├── custom_text_field.dart
│   ├── dashboard_widgets.dart     ← moved from screens/widgets/
│   ├── detail_widgets.dart        ← moved from screens/widgets/
│   ├── kpi_widgets.dart           ← moved from screens/widgets/
│   ├── report_overview_widgets.dart ← moved from screens/widgets/
│   ├── report_widgets.dart        ← moved from screens/widgets/
│   └── charts/
│       ├── report_chart.dart      ← moved from screens/widgets/charts/
│       ├── sales_bar_chart.dart   ← moved from screens/widgets/charts/
│       └── sales_purchase_combo_chart.dart ← moved from screens/widgets/charts/
└── screens/                        ← NOW ONLY contains screens (UI)
    ├── main.dart
    ├── sync_screen.dart
    ├── Analysis/
    │   └── (19 screen files - unchanged)
    ├── auth/
    │   └── (6 screen files - unchanged)
    ├── desktop/
    │   └── (2 screen files - unchanged)
    ├── home/
    │   └── (3 screen files - unchanged)
    ├── icons/
    │   └── app_icons.dart
    ├── mobile/
    │   └── (16 screen files - unchanged)
    └── theme/
        └── app_theme.dart
```

---

---

# Query Service Consolidation - Change Log

**Date:** 2026-03-28
**Purpose:** Extract all raw database queries from screen files into centralized service files under `lib/services/queries/`. Screens now call service methods instead of containing inline SQL.

---

## Summary

| Action | Count |
|--------|-------|
| New Service Files Created | 7 |
| Screen Files Modified | 14 |
| Total Query Functions Extracted | ~30 |

---

## 1. New Files Created

```
lib/services/queries/
  query_service.dart              -- barrel file (re-exports all services)
  voucher_query_service.dart      -- voucher details, payments, receipts
  ledger_query_service.dart       -- ledger listing, balances, trial balance
  group_query_service.dart        -- group-based ledger lists
  outstanding_query_service.dart  -- receivables, payables, bill-wise outstanding
  profit_loss_query_service.dart  -- P&L detailed, analysis summary
  stock_query_service.dart        -- stock items, transactions, costing
```

---

## 2. Service Functions Created

### `voucher_query_service.dart` (class `VoucherQueryService`)

| Method | Extracted From |
|--------|---------------|
| `getVoucherHeader()` | `voucher_detail_screen.dart` |
| `getVoucherLedgerEntries()` | `voucher_detail_screen.dart` |
| `fetchVouchersByType()` | `payment_screen.dart` + `receipt_screen.dart` (unified) |
| `fetchVoucherEntries()` | `payment_screen.dart` + `receipt_screen.dart` (unified) |

### `ledger_query_service.dart` (class `LedgerQueryService`)

| Method | Extracted From |
|--------|---------------|
| `getOpeningBalance()` | `ledger_detail_screen.dart` |
| `getLedgerVouchers()` | `ledger_detail_screen.dart` |
| `fetchLedgersWithBalances()` | `ledger_list_screen.dart` |
| `fetchDistinctGroups()` | `ledger_list_screen.dart` |
| `fetchPartyLedgers()` | `ledger_list_screen.dart` |
| `getTrialBalance()` | `trial_balance_screen.dart` |

### `group_query_service.dart` (class `GroupQueryService`)

| Method | Extracted From |
|--------|---------------|
| `getLedgersForGroup()` | `group_detail_screen.dart` (3 variants unified) |

### `outstanding_query_service.dart` (class `OutstandingQueryService`)

| Method | Extracted From |
|--------|---------------|
| `getBillWiseDetail()` | `bill_wise_detail_screen.dart` |
| `getBillWiseOutstandingLedgers()` | `bill_wise_outstanding_screen.dart` |
| `getReceivables()` | `party_outstanding_screen.dart` |
| `getPayables()` | `party_outstanding_screen.dart` |

### `stock_query_service.dart` (class `StockQueryService`)

| Method | Extracted From |
|--------|---------------|
| `getAvailableStockMonths()` | `stock_summary_screen.dart` |
| `fetchAllClosingStock()` | `stock_summary_screen.dart` + `profit_loss_screen2.dart` |
| `fetchAllStockItemsWithBatches()` | `profit_loss_screen2.dart` |
| `fetchTransactionsForStockItem()` | `profit_loss_screen2.dart` |
| `getAllChildVoucherTypes()` | `profit_loss_screen2.dart` |

### `profit_loss_query_service.dart` (class `ProfitLossQueryService`)

| Method | Extracted From |
|--------|---------------|
| `getAnalysisDetailed()` | `analysis_home_screen.dart` |
| `getProfitLossDetailed()` | `profit_loss_screen2.dart` |

---

## 3. Screen Files Modified

| Screen File | Change |
|-------------|--------|
| `screens/Analysis/voucher_detail_screen.dart` | Replaced 2 rawQuery calls with `VoucherQueryService` |
| `screens/Analysis/payment_screen.dart` | Replaced 2 rawQuery calls with `VoucherQueryService` |
| `screens/Analysis/receipt_screen.dart` | Replaced 2 rawQuery calls with `VoucherQueryService` |
| `screens/Analysis/ledger_detail_screen.dart` | Replaced 2 rawQuery calls with `LedgerQueryService` |
| `screens/Analysis/ledger_list_screen.dart` | Replaced 3 rawQuery functions with `LedgerQueryService` |
| `screens/Analysis/trial_balance_screen.dart` | Replaced 1 rawQuery call with `LedgerQueryService` |
| `screens/Analysis/bill_wise_detail_screen.dart` | Replaced 1 rawQuery call with `OutstandingQueryService` |
| `screens/Analysis/bill_wise_outstanding_screen.dart` | Replaced 1 rawQuery call with `OutstandingQueryService` |
| `screens/Analysis/party_outstanding_screen.dart` | Replaced 2 rawQuery calls with `OutstandingQueryService` |
| `screens/Analysis/group_detail_screen.dart` | Replaced 3 query variants with `GroupQueryService` |
| `screens/Analysis/stock_summary_screen.dart` | Replaced 2 rawQuery calls with `StockQueryService` |
| `screens/Analysis/profit_loss_screen2.dart` | Replaced 5 query functions with `StockQueryService` + `ProfitLossQueryService` |
| `screens/Analysis/analysis_home_screen.dart` | Replaced composite query function with `ProfitLossQueryService` |
| `screens/mobile/mobile_dashboard_tab.dart` | Replaced 6 duplicate rawQuery calls with `ProfitLossQueryService` |

---

## 4. Files NOT Modified (Per Plan)

| File | Reason |
|------|--------|
| `screens/home/analytics_dashboard.dart` | Entirely commented out |
| `screens/Analysis/ledger_reports_screen.dart` | Entirely commented out |
| `screens/Analysis/profit_loss_screen_edit.dart` | Entirely commented out |
| `screens/Analysis/cash_flow_screen.dart` | Empty stub, no queries |
| `screens/Analysis/gst_reports_screen.dart` | Empty stub, no queries |
| `screens/mobile/database_overview_screen.dart` | Debug tool with dynamic user SQL |
| `screens/desktop/database_viewer_screen.dart` | Debug tool for table inspection |
| `screens/Analysis/balance_sheet_screen.dart` | Complex FY-by-FY stock valuation (too tightly coupled to screen logic) |

---

*End of Change Log*
