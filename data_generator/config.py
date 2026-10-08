# config.py
# All settings for the fake bank in one place.

from datetime import date

# Same seed = same data every time you run the script
RANDOM_SEED = 42

# Time window of our fake bank
START_DATE = date(2025, 1, 1)       # first loan can be given from this date
LAST_DISBURSEMENT_DATE = date(2026, 3, 31)  # no new loans after this date
END_DATE = date(2026, 6, 30)        # "today" for our fake bank

# Size of the fake bank
NUM_CUSTOMERS = 5000
GROUP_SIZE_MIN = 5
GROUP_SIZE_MAX = 8
OFFICERS_PER_BRANCH = 3

# Branches: id, name, district, state
BRANCHES = [
    ("BR001", "Varanasi Main", "Varanasi", "Uttar Pradesh"),
    ("BR002", "Prayagraj Civil Lines", "Prayagraj", "Uttar Pradesh"),
    ("BR003", "Gorakhpur City", "Gorakhpur", "Uttar Pradesh"),
    ("BR004", "Patna Kankarbagh", "Patna", "Bihar"),
    ("BR005", "Gaya Town", "Gaya", "Bihar"),
    ("BR006", "Muzaffarpur Market", "Muzaffarpur", "Bihar"),
    ("BR007", "Ranchi Main Road", "Ranchi", "Jharkhand"),
    ("BR008", "Dhanbad Bank More", "Dhanbad", "Jharkhand"),
    ("BR009", "Bhopal New Market", "Bhopal", "Madhya Pradesh"),
    ("BR010", "Jabalpur Napier Town", "Jabalpur", "Madhya Pradesh"),
]

# These branches will have more bad groups (to create regional stress)
STRESSED_BRANCHES = ["BR005", "BR006"]

# Chance that a group is "high risk"
HIGH_RISK_GROUP_SHARE_NORMAL = 0.15
HIGH_RISK_GROUP_SHARE_STRESSED = 0.70

# Customer behaviour mix: (good, sometimes_late, defaulter)
BEHAVIOUR_LOW_RISK_GROUP = (0.85, 0.10, 0.05)
BEHAVIOUR_HIGH_RISK_GROUP = (0.40, 0.25, 0.35)

# Loan settings
PRINCIPAL_OPTIONS = [20000, 25000, 30000, 35000, 40000, 50000, 60000]
TENURE_OPTIONS = [12, 18, 24]
INTEREST_RATE_MIN = 22.0
INTEREST_RATE_MAX = 26.0

# Chance that a good customer takes a second loan after finishing the first
REPEAT_LOAN_CHANCE = 0.5

# Defaulter settings
DEFAULTER_RECOVERY_CHANCE = 0.3   # some defaulters pay all dues later
WRITEOFF_AFTER_DAYS = 365         # unpaid for this many days = written off

# Payment mode and posting delay
UPI_SHARE = 0.3                   # UPI is posted same day
CASH_POSTING_DELAY_DAYS = [0, 1, 2, 3]
CASH_POSTING_DELAY_WEIGHTS = [0.6, 0.2, 0.15, 0.05]

# Data quality issue on purpose: duplicate collection rows
DUPLICATE_COLLECTION_SHARE = 0.002

# Where files are saved
OUTPUT_FOLDER = "data/raw"