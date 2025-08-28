-- Test data for WOW Scales Verification System

-- Insert test clients
INSERT OR IGNORE INTO clients (client_name, address, phone, email) VALUES 
  ('ABC Manufacturing Ltd', '123 Industrial Ave, Johannesburg, 2000', '+27 11 123 4567', 'contact@abcmfg.co.za'),
  ('XYZ Logistics CC', '456 Transport Road, Cape Town, 8001', '+27 21 987 6543', 'info@xyzlogistics.co.za'),
  ('Test Client 1', '789 Test Street, Pretoria, 0001', '+27 12 555 0123', 'test1@example.com');

-- Insert test verifications
INSERT OR IGNORE INTO verifications (
  certificate_no, verification_date, verification_sticker, 
  client_id, status_type, accuracy_type
) VALUES 
  ('WOW-2025-0001', '2025-01-15', 'STICK001', 1, 'initial', 'tolerance'),
  ('WOW-2025-0002', '2025-01-16', 'STICK002', 2, 'subsequent', 'error'),
  ('WOW-2025-0003', '2025-01-17', 'STICK003', 3, 'initial', 'tolerance');

-- Insert test instruments
INSERT OR IGNORE INTO instruments (
  verification_id, manufacturer, model, serial_number,
  accuracy_class, units, max_capacity, max_test_load_available,
  verification_interval_e, min_capacity,
  sa_number, aa_number, software_version, sealing_method, equipment_notes
) VALUES 
  (1, 'Mettler Toledo', 'IND570', 'MT2025001', 'III', 'kg', 60000, 30000, 20, 400, 'SA-WT-001', 'AA-12345', 'v2.1.3', 'Electronic seal', 'Standard weights 1kg-20t set'),
  (2, 'Avery Weigh-Tronix', 'ZM510', 'AWT2025002', 'III', 'kg', 3000, 3000, 1, 20, 'SA-WT-002', 'AA-67890', 'v1.5.2', 'Wire & lead seal', 'Calibrated weights OIML M1 class'),
  (3, 'Cardinal Scale', 'DL-1000', 'CS2025003', 'II', 'g', 1000, 1000, 0.1, 2, 'SA-WT-003', 'AA-11111', 'v3.0.1', 'Software protection', 'Precision weights set F1 class');

-- Insert test accuracy results
INSERT OR IGNORE INTO accuracy_tests (
  verification_id, test_load, make_up, indication,
  run_up_load, run_down_load, switch_point_load,
  error_value, band, mpe_value, result
) VALUES 
  (1, 400, 'Standard weights 400kg', NULL, 399.95, 400.05, 400.0, 0.0, '0-500e', 10, 'PASS'),
  (1, 10020, 'Standard 10t + substitute 20kg', NULL, 10019.9, 10020.1, 10020.0, 0.0, '501-2000e', 20, 'PASS'),
  (1, 30000, 'Standard 15t + substitute 15t', NULL, 29999.8, 30000.2, 30000.0, 0.0, '501-2000e', 20, 'PASS'),
  (2, 20, 'Standard weights 20kg', NULL, 19.95, 20.05, 20.0, 0.0, '0-500e', 0.5, 'PASS'),
  (2, 1500, 'Standard 1t + substitute 500kg', NULL, 1499.9, 1500.1, 1500.0, 0.0, '501-2000e', 1.0, 'PASS'),
  (3, 2, 'Standard weights 2g', NULL, 1.99, 2.01, 2.0, 0.0, '0-500e', 0.05, 'PASS');

-- Insert test variation results  
INSERT OR IGNORE INTO variation_tests (
  verification_id, applied_load, reference_indication,
  end1_indication, middle_indication, end2_indication
) VALUES 
  (1, '15000kg mixed load', 15000.2, 15000.1, 15000.2, 15000.0),
  (2, '750kg standard weights', 750.1, 750.0, 750.1, 750.1),
  (3, '500g precision weights', 500.05, 500.04, 500.05, 500.06);

-- Insert test repeatability results
INSERT OR IGNORE INTO repeatability_tests (
  verification_id, target_test_load, run1_indication, run2_indication, run3_indication
) VALUES 
  (1, 54000, 54000.1, 54000.0, 54000.1),
  (2, 2700, 2700.0, 2700.1, 2700.0), 
  (3, 900, 900.02, 900.03, 900.01);

-- Insert test verification officers
INSERT OR IGNORE INTO verification_officers (
  verification_id, officer_name, officer_id, sanas_lab_no, seal_id, signature
) VALUES 
  (1, 'J. Smith', 'VO001', 'SANAS-123', 'SEAL2025001', 'J. Smith'),
  (2, 'M. Johnson', 'VO002', 'SANAS-123', 'SEAL2025002', 'M. Johnson'),
  (3, 'A. Williams', 'VO003', 'SANAS-123', 'SEAL2025003', 'A. Williams');
