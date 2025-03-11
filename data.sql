-- pg_dump: warning: there are circular foreign-key constraints on this table:
-- pg_dump: detail: key
-- pg_dump: hint: You might not be able to restore the dump without using --disable-triggers or temporarily dropping the constraints.
-- pg_dump: hint: Consider using a full dump instead of a --data-only dump to avoid this problem.
-- --
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: tenants; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.tenants (id, name, external_id, jwt_secret, max_concurrent_users, inserted_at, updated_at, max_events_per_second, postgres_cdc_default, max_bytes_per_second, max_channels_per_client, max_joins_per_second, suspend, jwt_jwks, notify_private_alpha, private_only) FROM stdin;
2bdf2307-b9ee-470d-9d92-9a248e6e0b75	realtime-dev	realtime-dev	eGxa2ZKVreSn7eWieRQdp60i5H6KJLiST7splFU6MVHylMSAoQ2SjsTrTTQo/+bmYjQcO4hNnGTU+D1wtlXreA==	200	2025-03-11 05:45:03	2025-03-11 05:45:03	100	postgres_cdc_rls	100000	100	100	f	\N	f	f
\.


--
-- Data for Name: extensions; Type: TABLE DATA; Schema: _realtime; Owner: -
--

-- THIS BREAKS SHIT - COPY _realtime.extensions (id, type, settings, tenant_external_id, inserted_at, updated_at) FROM stdin;
-- 580688be-be75-4157-b600-14ad10fc93c4	postgres_cdc_rls	{"region": "us-east-1", "db_host": "QhixI0o7PYIABziLUL4f0A==", "db_name": "sWBpZNdjggEPTQVlI52Zfw==", "db_port": "+enMDFi1J/3IrrquHHwUmA==", "db_user": "uxbEq/zz8DXVD53TOI1zmw==", "slot_name": "supabase_realtime_replication_slot", "db_password": "eGxa2ZKVreSn7eWieRQdp74vN25K+qFgdnxmDCKe4p20+C0410WXonzXTEj9CgYx", "publication": "supabase_realtime", "ssl_enforced": false, "poll_interval_ms": 100, "poll_max_changes": 100, "poll_max_record_bytes": 1048576}	realtime-dev	2025-03-11 05:45:03	2025-03-11 05:45:03
-- \.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: _realtime; Owner: -
--

COPY _realtime.schema_migrations (version, inserted_at) FROM stdin;
20210706140551	2025-03-11 05:45:01
20220329161857	2025-03-11 05:45:01
20220410212326	2025-03-11 05:45:01
20220506102948	2025-03-11 05:45:01
20220527210857	2025-03-11 05:45:01
20220815211129	2025-03-11 05:45:01
20220815215024	2025-03-11 05:45:02
20220818141501	2025-03-11 05:45:02
20221018173709	2025-03-11 05:45:02
20221102172703	2025-03-11 05:45:02
20221223010058	2025-03-11 05:45:02
20230110180046	2025-03-11 05:45:02
20230810220907	2025-03-11 05:45:02
20230810220924	2025-03-11 05:45:02
20231024094642	2025-03-11 05:45:02
20240306114423	2025-03-11 05:45:02
20240418082835	2025-03-11 05:45:02
20240625211759	2025-03-11 05:45:03
20240704172020	2025-03-11 05:45:03
20240902173232	2025-03-11 05:45:03
20241106103258	2025-03-11 05:45:03
\.


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid) FROM stdin;
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: key; Type: TABLE DATA; Schema: pgsodium; Owner: -
--

COPY pgsodium.key (id, status, created, expires, key_type, key_id, key_context, name, associated_data, raw_key, raw_key_nonce, parent_key, comment, user_data) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2025-03-11 05:45:15
20211116045059	2025-03-11 05:45:15
20211116050929	2025-03-11 05:45:15
20211116051442	2025-03-11 05:45:15
20211116212300	2025-03-11 05:45:15
20211116213355	2025-03-11 05:45:15
20211116213934	2025-03-11 05:45:15
20211116214523	2025-03-11 05:45:15
20211122062447	2025-03-11 05:45:15
20211124070109	2025-03-11 05:45:15
20211202204204	2025-03-11 05:45:15
20211202204605	2025-03-11 05:45:15
20211210212804	2025-03-11 05:45:15
20211228014915	2025-03-11 05:45:15
20220107221237	2025-03-11 05:45:15
20220228202821	2025-03-11 05:45:15
20220312004840	2025-03-11 05:45:15
20220603231003	2025-03-11 05:45:15
20220603232444	2025-03-11 05:45:15
20220615214548	2025-03-11 05:45:15
20220712093339	2025-03-11 05:45:15
20220908172859	2025-03-11 05:45:15
20220916233421	2025-03-11 05:45:15
20230119133233	2025-03-11 05:45:16
20230128025114	2025-03-11 05:45:16
20230128025212	2025-03-11 05:45:16
20230227211149	2025-03-11 05:45:16
20230228184745	2025-03-11 05:45:16
20230308225145	2025-03-11 05:45:16
20230328144023	2025-03-11 05:45:16
20231018144023	2025-03-11 05:45:16
20231204144023	2025-03-11 05:45:16
20231204144024	2025-03-11 05:45:16
20231204144025	2025-03-11 05:45:16
20240108234812	2025-03-11 05:45:16
20240109165339	2025-03-11 05:45:16
20240227174441	2025-03-11 05:45:16
20240311171622	2025-03-11 05:45:16
20240321100241	2025-03-11 05:45:16
20240401105812	2025-03-11 05:45:16
20240418121054	2025-03-11 05:45:16
20240523004032	2025-03-11 05:45:16
20240618124746	2025-03-11 05:45:16
20240801235015	2025-03-11 05:45:16
20240805133720	2025-03-11 05:45:16
20240827160934	2025-03-11 05:45:16
20240919163303	2025-03-11 05:45:16
20240919163305	2025-03-11 05:45:16
20241019105805	2025-03-11 05:45:16
20241030150047	2025-03-11 05:45:16
20241108114728	2025-03-11 05:45:16
20241121104152	2025-03-11 05:45:16
20241130184212	2025-03-11 05:45:16
20241220035512	2025-03-11 05:45:16
20241220123912	2025-03-11 05:45:16
20241224161212	2025-03-11 05:45:16
20250107150512	2025-03-11 05:45:17
20250110162412	2025-03-11 05:45:17
20250123174212	2025-03-11 05:45:17
20250128220012	2025-03-11 05:45:17
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2025-03-11 05:45:01.225859
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2025-03-11 05:45:01.267028
2	storage-schema	5c7968fd083fcea04050c1b7f6253c9771b99011	2025-03-11 05:45:01.333702
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2025-03-11 05:45:01.384531
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2025-03-11 05:45:01.901841
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2025-03-11 05:45:01.967677
6	change-column-name-in-get-size	f93f62afdf6613ee5e7e815b30d02dc990201044	2025-03-11 05:45:02.043524
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2025-03-11 05:45:02.126672
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2025-03-11 05:45:02.184985
9	fix-search-function	3a0af29f42e35a4d101c259ed955b67e1bee6825	2025-03-11 05:45:02.269392
10	search-files-search-function	68dc14822daad0ffac3746a502234f486182ef6e	2025-03-11 05:45:02.360534
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2025-03-11 05:45:02.455101
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2025-03-11 05:45:02.51075
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2025-03-11 05:45:02.606168
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2025-03-11 05:45:02.687333
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2025-03-11 05:45:02.962032
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2025-03-11 05:45:03.020976
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2025-03-11 05:45:03.071192
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2025-03-11 05:45:03.110282
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2025-03-11 05:45:03.213175
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2025-03-11 05:45:03.24348
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2025-03-11 05:45:03.413782
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2025-03-11 05:45:03.823912
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2025-03-11 05:45:04.640782
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2025-03-11 05:45:04.746268
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2025-03-11 05:45:04.795078
26	objects-prefixes	ef3f7871121cdc47a65308e6702519e853422ae2	2025-03-11 05:45:04.853401
27	search-v2	33b8f2a7ae53105f028e13e9fcda9dc4f356b4a2	2025-03-11 05:45:05.045764
28	object-bucket-name-sorting	8f385d71c72f7b9f6388e22f6e393e3b78bf8617	2025-03-11 05:45:05.296506
29	create-prefixes	8416491709bbd2b9f849405d5a9584b4f78509fb	2025-03-11 05:45:05.313935
30	update-object-levels	f5899485e3c9d05891d177787d10c8cb47bae08a	2025-03-11 05:45:05.330311
31	objects-level-index	33f1fef7ec7fea08bb892222f4f0f5d79bab5eb8	2025-03-11 05:45:05.513729
32	backward-compatible-index-on-objects	2d51eeb437a96868b36fcdfb1ddefdf13bef1647	2025-03-11 05:45:05.779878
33	backward-compatible-index-on-prefixes	fe473390e1b8c407434c0e470655945b110507bf	2025-03-11 05:45:06.038359
34	optimize-search-function-v1	82b0e469a00e8ebce495e29bfa70a0797f7ebd2c	2025-03-11 05:45:06.098855
35	add-insert-trigger-prefixes	63bb9fd05deb3dc5e9fa66c83e82b152f0caf589	2025-03-11 05:45:06.121933
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata, level) FROM stdin;
\.


--
-- Data for Name: prefixes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.prefixes (bucket_id, name, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: hooks; Type: TABLE DATA; Schema: supabase_functions; Owner: -
--

COPY supabase_functions.hooks (id, hook_table_id, hook_name, created_at, request_id) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: supabase_functions; Owner: -
--

COPY supabase_functions.migrations (version, inserted_at) FROM stdin;
initial	2025-03-11 05:44:36.830687+00
20210809183423_update_grants	2025-03-11 05:44:36.830687+00
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 1, false);


--
-- Name: key_key_id_seq; Type: SEQUENCE SET; Schema: pgsodium; Owner: -
--

SELECT pg_catalog.setval('pgsodium.key_key_id_seq', 1, false);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- Name: hooks_id_seq; Type: SEQUENCE SET; Schema: supabase_functions; Owner: -
--

SELECT pg_catalog.setval('supabase_functions.hooks_id_seq', 1, false);


--
-- PostgreSQL database dump complete
--

