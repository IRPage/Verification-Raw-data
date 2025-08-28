-- WOW Scales Verification System Database Schema
-- Based on Legal Metrology Regulation No 877 and SANS 1649:2014

-- Clients table
CREATE TABLE IF NOT EXISTS clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_name TEXT NOT NULL,
    address TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Main verification records
CREATE TABLE IF NOT EXISTS verifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    certificate_no TEXT UNIQUE NOT NULL,
    verification_date DATE NOT NULL,
    verification_sticker TEXT,
    client_id INTEGER REFERENCES clients(id),
    status_type TEXT CHECK (status_type IN ('initial', 'subsequent')) DEFAULT 'initial',
    accuracy_type TEXT CHECK (accuracy_type IN ('tolerance', 'error')) DEFAULT 'tolerance',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Instrument details
CREATE TABLE IF NOT EXISTS instruments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    manufacturer TEXT NOT NULL,
    model TEXT NOT NULL,
    serial_number TEXT NOT NULL,
    accuracy_class TEXT CHECK (accuracy_class IN ('I', 'II', 'III', 'IIII')) DEFAULT 'III',
    units TEXT CHECK (units IN ('kg', 'g', 'mg', 't', 'ct')) DEFAULT 'kg',
    max_capacity REAL NOT NULL,
    max_test_load_available REAL,
    verification_interval_e REAL NOT NULL,
    min_capacity REAL, -- Auto-calculated as 20 × e
    sa_number TEXT, -- South African type approval number
    aa_number TEXT, -- Additional approval number
    software_version TEXT,
    sealing_method TEXT,
    equipment_notes TEXT, -- Verification equipment used
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Accuracy testing results (AA.2.2.5)
CREATE TABLE IF NOT EXISTS accuracy_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    test_load REAL, -- Applied load (L)
    make_up TEXT, -- Load composition description
    indication REAL, -- Scale indication (if no changeover testing)
    run_up_load REAL, -- Load when approaching from below (±0.1e steps)
    run_down_load REAL, -- Load when approaching from above (±0.1e steps)
    switch_point_load REAL, -- Average of run_up and run_down
    error_value REAL, -- Switch Point L - L or Indication - L
    band TEXT, -- Which MPE band (0-500e, 501-2000e, 2001-10000e)
    mpe_value REAL, -- Maximum Permissible Error for this load
    result TEXT CHECK (result IN ('PASS', 'FAIL')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Variation/Shift testing (End → Middle → End)
CREATE TABLE IF NOT EXISTS variation_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    applied_load TEXT, -- Load description (can be text like "55460/80")
    reference_indication REAL, -- Middle position reference
    end1_indication REAL, -- First end position
    middle_indication REAL, -- Middle position
    end2_indication REAL, -- Second end position
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Repeatability testing (3 runs near ~90% Max)
CREATE TABLE IF NOT EXISTS repeatability_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    target_test_load REAL, -- Target load (~0.9 × Max)
    run1_indication REAL,
    run2_indication REAL,
    run3_indication REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Zero setting test results (AA.2.2.4)
CREATE TABLE IF NOT EXISTS zero_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    test_type TEXT CHECK (test_type IN ('semi_auto', 'auto_zero', 'zero_tracking')),
    delta_l_value REAL, -- Additional load needed for display change
    result TEXT CHECK (result IN ('PASS', 'FAIL', 'N/A')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tare device accuracy testing (AA.2.2.6)
CREATE TABLE IF NOT EXISTS tare_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    applied_tare REAL,
    indication REAL,
    error_value REAL,
    mpe_value REAL,
    result TEXT CHECK (result IN ('PASS', 'FAIL')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Eccentricity testing (AA.2.2.7)
CREATE TABLE IF NOT EXISTS eccentricity_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    position TEXT, -- 'End', 'Middle', etc.
    test_load REAL,
    indication REAL,
    error_value REAL,
    mpe_value REAL,
    result TEXT CHECK (result IN ('PASS', 'FAIL')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Verification officers
CREATE TABLE IF NOT EXISTS verification_officers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    verification_id INTEGER REFERENCES verifications(id),
    officer_name TEXT,
    officer_id TEXT,
    sanas_lab_no TEXT,
    seal_id TEXT,
    signature TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_verifications_certificate_no ON verifications(certificate_no);
CREATE INDEX IF NOT EXISTS idx_verifications_date ON verifications(verification_date);
CREATE INDEX IF NOT EXISTS idx_verifications_client_id ON verifications(client_id);
CREATE INDEX IF NOT EXISTS idx_instruments_verification_id ON instruments(verification_id);
CREATE INDEX IF NOT EXISTS idx_accuracy_tests_verification_id ON accuracy_tests(verification_id);
CREATE INDEX IF NOT EXISTS idx_clients_name ON clients(client_name);
