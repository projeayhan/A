-- job_listing_status enum'una 'inactive' degeri ekle
-- Diger tablolar (car_listings, properties, rental_cars, products) varchar/text kullandigi icin
-- bu duzeltme sadece job_listings icin gerekli
ALTER TYPE job_listing_status ADD VALUE IF NOT EXISTS 'inactive';
