# Offline Vietnamese administrative catalog

The profile selector uses the two-level post-July-2025 hierarchy: province/city directly to commune/ward/special administrative zone. No district selector is present. All choices are bundled; the application makes no HTTP requests for addresses.

Snapshot: Vietnamese Provinces Database v5.2.0, generated 2026-09-20T13:13:17Z, latest tracked decree 388/NQ-UBTVQH16. Retrieved and reviewed on 2026-10-30. 34 provincial units and 3,321 commune-level units; codes retained as zero-padded strings. Only code, full name and parent relationships are retained; postal and GIS data are excluded.

Machine-readable source, pinned to commit 8b78ba5118715e1fa81769286724db79346abf52 (2026-09-22):
https://raw.githubusercontent.com/thanglequoc/vietnamese-provinces-database/8b78ba5118715e1fa81769286724db79346abf52/json/vn_only_simplified_json_generated_data_vn_units_minified.json

Upstream: https://github.com/thanglequoc/vietnamese-provinces-database . This is a community dataset derived from the National Statistics Office, not an official government API supplied by the app. MIT license included in docs/licenses and in the APK assets/data/vn-admin-LICENSE.txt.

Official basis and checked updates:
- Decision 19/2025/QD-TTg, effective 2025-07-01: https://chinhphu.vn/?classid=1&docid=214409&orggroupid=3&pageid=27160
- National Statistics Office catalog: https://danhmuchanhchinh.nso.gov.vn/
- Resolution 36/2026/QH16 (Quang Ninh city, effective 2026-09-01): https://chinhphu.vn/?classid=1&docid=219325&pageid=27160
- Resolution 39/2026/QH16 (Bac Ninh city, effective 2026-09-20): https://chinhphu.vn/?classid=0&docid=219328&pageid=27160
- Resolution 388/NQ-UBTVQH16, ward changes effective 2026-09-20: https://congbao.chinhphu.vn/van-ban-dang-cong-bao/nghi-quyet-l6/trang-3.htm

The app uses a versioned snapshot, not a promise of automatic future updates. Refresh the pinned data and provenance, validate unique codes and parent relationships, and ship a new app build when administrative units change. Search accepts Vietnamese with or without accents and administrative codes. Changing a province clears the ward; cancelling a selector leaves values unchanged. The commune-level selector includes special administrative zones under the requested Phuong/Xa label.
