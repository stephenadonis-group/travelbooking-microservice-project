# TravelBooking — PostgreSQL Database Guide

This guide explains how to connect to the PostgreSQL database running inside the GKE cluster and query all the application data.

---

## How the Database is Set Up

The TravelBooking app uses **1 PostgreSQL pod** running as a StatefulSet with **5 separate databases** inside it:

| Database | Used By | What It Stores |
|----------|---------|----------------|
| `userdb` | user-service | Registered user accounts |
| `searchdb` | search-service | Available flights and hotels |
| `bookingdb` | booking-service | Flight and hotel bookings |
| `paymentdb` | payment-service | Payment transactions |
| `notificationdb` | notification-service | User notifications |

---

## Step 1: Connect to the PostgreSQL Pod

First, make sure you're connected to the GKE cluster:

```bash
gcloud container clusters get-credentials <CLUSTER_NAME> --zone <ZONE> --project <PROJECT_ID>
```

### Option A: Run a Single Query (Quick)

```bash
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d <database_name> -c "<SQL query>"
```

**Example:**
```bash
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d userdb -c "SELECT * FROM users;"
```

### Option B: Open an Interactive PostgreSQL Shell

```bash
kubectl exec -it -n travel-booking postgres-0 -- psql -U postgres
```

Once inside the `psql` shell, you'll see the `postgres=#` prompt. From here you can:

```sql
-- List all databases
\l

-- Connect to a specific database
\c userdb

-- List all tables in the current database
\dt

-- Show columns of a table
\d users

-- Run any SQL query
SELECT * FROM users;

-- Exit the shell
\q
```

---

## Step 2: Query Each Database

### Database 1: `userdb` — Registered Users

The `users` table stores all registered accounts.

**Columns:**

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique user ID |
| name | TEXT | User's full name |
| email | TEXT | Email address (unique) |
| password | TEXT | Hashed password |
| role | VARCHAR(20) | User role (default: `traveler`) |
| created_at | TIMESTAMP | When the account was created |
| updated_at | TIMESTAMP | When the account was last updated |

**Commands:**

```bash
# See all registered users
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d userdb -c "SELECT id, name, email, role, created_at FROM users ORDER BY created_at DESC;"

# Count total users
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d userdb -c "SELECT COUNT(*) AS total_users FROM users;"

# Find a specific user by email
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d userdb -c "SELECT id, name, email, role FROM users WHERE email = 'vijay@gmail.com';"

# See users registered today
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d userdb -c "SELECT id, name, email, created_at FROM users WHERE created_at::date = CURRENT_DATE;"
```

---

### Database 2: `searchdb` — Flights and Hotels

#### Flights Table

The `flights` table stores all available flights.

**Columns:**

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique flight ID |
| flight_number | TEXT | Flight number (e.g., `Em100`) |
| airline | TEXT | Airline name (e.g., `Emirates`) |
| origin | TEXT | Departure airport code (e.g., `NYC`) |
| destination | TEXT | Arrival airport code (e.g., `LAX`) |
| departure_time | TIMESTAMP | Departure date and time |
| arrival_time | TIMESTAMP | Arrival date and time |
| duration | TEXT | Flight duration (e.g., `5h 30m`) |
| price | NUMERIC | Ticket price in USD |
| available_seats | INTEGER | Number of available seats |
| class | VARCHAR(20) | Cabin class (`economy` or `business`) |

**Commands:**

```bash
# See all flights
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT id, flight_number, airline, origin, destination, price, available_seats, class FROM flights ORDER BY price;"

# Count total flights
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT COUNT(*) AS total_flights FROM flights;"

# Search flights from NYC to LAX
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT flight_number, airline, origin, destination, price, class FROM flights WHERE origin = 'NYC' AND destination = 'LAX';"

# See all unique routes
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT DISTINCT origin, destination FROM flights ORDER BY origin;"

# Find cheapest flights
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT flight_number, airline, origin, destination, price FROM flights ORDER BY price ASC LIMIT 5;"

# Find most expensive flights
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT flight_number, airline, origin, destination, price FROM flights ORDER BY price DESC LIMIT 5;"

# See flights grouped by airline
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT airline, COUNT(*) AS num_flights, ROUND(AVG(price), 2) AS avg_price FROM flights GROUP BY airline ORDER BY num_flights DESC;"
```

#### Hotels Table

The `hotels` table stores all available hotels.

**Columns:**

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique hotel ID |
| name | TEXT | Hotel name |
| city | TEXT | City where the hotel is located |
| address | TEXT | Street address |
| rating | NUMERIC(3,1) | Star rating (e.g., `4.5`) |
| price_per_night | NUMERIC | Price per night in USD |
| available_rooms | INTEGER | Number of rooms available |
| amenities | JSONB | List of amenities (WiFi, Pool, etc.) |
| description | TEXT | Hotel description |

**Commands:**

```bash
# See all hotels
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT id, name, city, rating, price_per_night, available_rooms FROM hotels ORDER BY rating DESC;"

# Count total hotels
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT COUNT(*) AS total_hotels FROM hotels;"

# Search hotels in Paris
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT name, city, rating, price_per_night FROM hotels WHERE city = 'Paris' ORDER BY rating DESC;"

# Find hotels by minimum rating (4.5+)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT name, city, rating, price_per_night FROM hotels WHERE rating >= 4.5 ORDER BY rating DESC;"

# Find cheapest hotels
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT name, city, price_per_night FROM hotels ORDER BY price_per_night ASC LIMIT 5;"

# See hotels grouped by city
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT city, COUNT(*) AS num_hotels, ROUND(AVG(price_per_night), 2) AS avg_price FROM hotels GROUP BY city ORDER BY num_hotels DESC;"

# See all unique cities with hotels
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT DISTINCT city FROM hotels ORDER BY city;"
```

---

### Database 3: `bookingdb` — Bookings

The `bookings` table stores all flight and hotel bookings.

**Columns:**

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique booking ID |
| user_id | UUID | Who made the booking (references users table) |
| type | VARCHAR(20) | Booking type: `flight` or `hotel` |
| reference_id | TEXT | The flight ID or hotel ID that was booked |
| status | VARCHAR(20) | Booking status: `confirmed`, `cancelled`, or `pending` |
| total_amount | NUMERIC | Total price paid |
| passenger_details | TEXT | Passenger info (name, email, phone) as JSON |
| booking_date | TIMESTAMP | When the booking was made |
| travel_date | TIMESTAMP | Departure or check-in date |

**Commands:**

```bash
# See all bookings
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT id, user_id, type, status, total_amount, travel_date FROM bookings ORDER BY booking_date DESC;"

# Count total bookings
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT COUNT(*) AS total_bookings FROM bookings;"

# See only flight bookings
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT id, user_id, status, total_amount, travel_date FROM bookings WHERE type = 'flight' ORDER BY booking_date DESC;"

# See only hotel bookings
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT id, user_id, status, total_amount, travel_date FROM bookings WHERE type = 'hotel' ORDER BY booking_date DESC;"

# See confirmed bookings only
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT id, type, total_amount, travel_date FROM bookings WHERE status = 'confirmed' ORDER BY travel_date;"

# See cancelled bookings only
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT id, type, total_amount, travel_date FROM bookings WHERE status = 'cancelled' ORDER BY booking_date DESC;"

# Count bookings by status
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT status, COUNT(*) AS count, SUM(total_amount) AS total_revenue FROM bookings GROUP BY status;"

# Count bookings by type (flight vs hotel)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT type, COUNT(*) AS count, SUM(total_amount) AS total_revenue FROM bookings GROUP BY type;"

# See bookings for a specific user (replace USER_ID)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT id, type, status, total_amount, travel_date FROM bookings WHERE user_id = 'USER_ID_HERE';"

# See passenger details for all bookings
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT id, type, status, total_amount, passenger_details FROM bookings ORDER BY booking_date DESC;"

# Total revenue from all confirmed bookings
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT SUM(total_amount) AS total_revenue FROM bookings WHERE status = 'confirmed';"
```

---

### Database 4: `paymentdb` — Payments

The `payments` table stores all payment transactions.

**Columns:**

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Unique payment ID |
| booking_id | UUID | Which booking this payment is for |
| user_id | UUID | Who made the payment |
| amount | NUMERIC | Payment amount in USD |
| currency | VARCHAR(3) | Currency code (default: `USD`) |
| status | VARCHAR(20) | Payment status: `success`, `failed`, or `pending` |
| payment_method | TEXT | Card details (last4, brand) as JSON |
| transaction_id | TEXT | Unique transaction reference (e.g., `TXN_730D0210...`) |
| failure_reason | TEXT | Reason if payment failed (null if success) |

**Commands:**

```bash
# See all payments
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT id, booking_id, amount, currency, status, transaction_id FROM payments ORDER BY created_at DESC;"

# Count total payments
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT COUNT(*) AS total_payments FROM payments;"

# See successful payments only
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT id, booking_id, amount, status, transaction_id FROM payments WHERE status = 'success' ORDER BY created_at DESC;"

# See failed payments (if any)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT id, booking_id, amount, status, failure_reason FROM payments WHERE status = 'failed';"

# Total money collected (successful payments)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT COUNT(*) AS total_transactions, SUM(amount) AS total_collected, currency FROM payments WHERE status = 'success' GROUP BY currency;"

# See payment method details (card brand, last 4 digits)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT id, amount, status, payment_method, transaction_id FROM payments ORDER BY created_at DESC;"

# Payments for a specific booking (replace BOOKING_ID)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT id, amount, status, transaction_id FROM payments WHERE booking_id = 'BOOKING_ID_HERE';"
```

---

### Database 5: `notificationdb` — Notifications

The `notifications` table stores user notifications (booking confirmations, etc.).

**Commands:**

```bash
# See all notifications
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d notificationdb -c "SELECT * FROM notifications ORDER BY created_at DESC;"

# Count total notifications
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d notificationdb -c "SELECT COUNT(*) AS total FROM notifications;"

# See notification table structure
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d notificationdb -c "\d notifications"
```

---

## Useful Dashboard Queries

These queries give you a quick summary of the entire application:

```bash
# ─── Full Application Summary ─────────────────────────────────────────────────

# Total registered users
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d userdb -c "SELECT COUNT(*) AS registered_users FROM users;"

# Total flights and hotels available
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d searchdb -c "SELECT (SELECT COUNT(*) FROM flights) AS total_flights, (SELECT COUNT(*) FROM hotels) AS total_hotels;"

# Booking summary (by type and status)
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d bookingdb -c "SELECT type, status, COUNT(*) AS count, SUM(total_amount) AS revenue FROM bookings GROUP BY type, status ORDER BY type, status;"

# Payment summary
kubectl exec -n travel-booking postgres-0 -- psql -U postgres -d paymentdb -c "SELECT status, COUNT(*) AS count, SUM(amount) AS total FROM payments GROUP BY status;"
```

---

## Quick Copy-Paste: Interactive Shell

If you want to explore freely, open the PostgreSQL shell and switch between databases:

```bash
# Open the shell
kubectl exec -it -n travel-booking postgres-0 -- psql -U postgres

# Inside psql:
\c userdb
SELECT * FROM users;

\c searchdb
SELECT * FROM flights;
SELECT * FROM hotels;

\c bookingdb
SELECT * FROM bookings;

\c paymentdb
SELECT * FROM payments;

\c notificationdb
SELECT * FROM notifications;

\q
```

---

## Connection Details

| Setting | Value |
|---------|-------|
| **Host** | `postgres` (inside cluster) |
| **Port** | `5432` |
| **Username** | `postgres` |
| **Password** | `postgres` |
| **Pod Name** | `postgres-0` |
| **Namespace** | `travel-booking` |
| **Databases** | `userdb`, `searchdb`, `bookingdb`, `paymentdb`, `notificationdb` |
