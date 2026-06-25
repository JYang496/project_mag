# Rest Area Service Menu Contract

Rest-area services must use the shared primary-menu flow. A service should not
open a custom first-level menu inside its secondary panel.

## Required Flow

1. Add the service primary menu under `UI/scenes/UI.tscn` as:
   `GUI/<ServiceRoot>/PrimaryMenuRoot/Panel`.
2. Register the service id in `RestAreaUiController.SERVICE_MENU_IDS`.
3. Expose its primary root, panel, and buttons through:
   - `get_service_primary_root(menu_id)`
   - `get_service_primary_panel(menu_id)`
   - `get_service_primary_buttons(menu_id)`
4. Open the service only through `RestAreaUiController.open_menu(menu_id)`.
5. Primary-menu buttons may open secondary panels, but secondary panels must not
   implement their own service-level menu.
6. Right-click/cancel behavior must be:
   - secondary panel -> service primary menu
   - service primary menu -> close service menu
7. Zone navigation must be:
   - allowed while only the service primary menu is visible
   - blocked while any secondary management panel is visible

## Verification

Any new service must update or pass:

- `World/Test/management_ui_polish_test.tscn`
  - validates every registered service primary menu uses shared layout/style
- `World/Test/rest_area_zone_hint_test.tscn`
  - validates service primary/secondary menu visibility and zone navigation lock
- `godot --headless --path . --check-only --quit`

