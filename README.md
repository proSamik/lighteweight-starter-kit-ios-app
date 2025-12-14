# Lightweight Starter Kit - iOS + Mac App using SwiftUI

## How it looks?

| Sign-in | Onboarding page | Profile Page | Upload Profile Pic |
|---------|-----------------|--------------|--------------|
| <img width="312" height="681" alt="Screenshot 2025-11-30 at 15 38 49" src="https://github.com/user-attachments/assets/612f2370-febf-4f7a-9481-976c0462c0ff" /> | <img width="312" height="681" alt="Screenshot 2025-11-30 at 15 35 34" src="https://github.com/user-attachments/assets/2d64a731-8587-42e5-9239-80fb46948ec5" /> | <img width="312" height="681" alt="Screenshot 2025-11-30 at 15 36 52" src="https://github.com/user-attachments/assets/18a937dc-cf33-4f73-bbba-f258b856b63c" /> | <img width="312" height="681" alt="Screenshot 2025-11-30 at 15 38 49" src="https://github.com/user-attachments/assets/68bd704d-8539-4af9-96cc-f3ddf8b11edf" /> |

---

## This comes with- 
- 1/ Login using Apple and Google using Supabase
- 2/ Widget which you can customise
- 3/ Revenue Cat Payments
- 4/ App Lock in-built (FACE ID & PIN)
- 5/ Navigation Stack to extend more than one View
- 6/ Theme manager to manually manage theme

## Project Overview: Follow this guide step-by-step

## 0- Watch this Intro Video about this Starter Repo
https://www.youtube.com/watch?v=81GiWxq-NSw

## 1- Setup Supabase Sign-in: Create new Supabase Project
- Watch this YouTube video on how to setup public API Key for Supabase

https://www.youtube.com/watch?v=QEqOaOYHOYU&t=206s

## 2- Setup Apple Sign-in: Allow Social sign in and allow from Apple Developers

https://www.youtube.com/watch?v=E1j70_Up6aU

## 3- Setup Google Sign-in: Allow Google sign in and setup Google console

https://www.youtube.com/watch?v=8QGghYtaX04

## 4- For RevenueCat setup watch these 2 videos:

- 1/ RevenueCat Dashboard setup-

https://www.youtube.com/watch?v=X6xesg7YrU0
  
- 2/ RevenueCat Code setup for API-

https://www.youtube.com/watch?v=8LA1O_ykskA

## 5- Setup SQL: Create fresh database setup

Copy and paste these SQL commands in your Supabase SQL Editor:

```sql
-- Create profiles table (extends auth.users)
CREATE TABLE profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  name TEXT,
  profile_image_url TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Create quotes table for user-specific quotes
CREATE TABLE quotes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
  text TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;

-- Create policies for profiles table
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Create policies for quotes table
CREATE POLICY "Users can view own quotes" ON quotes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own quotes" ON quotes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own quotes" ON quotes
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own quotes" ON quotes
  FOR DELETE USING (auth.uid() = user_id);

-- Create function to handle new user profile creation with name and profile image
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, profile_image_url)
  VALUES (
    NEW.id, 
    NEW.email, 
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'profile_image_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create profile on user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();

CREATE TRIGGER quotes_updated_at
  BEFORE UPDATE ON quotes
  FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();
```

#### Use this after the first one is done

```sql
-- Add new columns to the quotes table
ALTER TABLE quotes
ADD COLUMN is_favorite BOOLEAN DEFAULT FALSE NOT NULL,
ADD COLUMN author TEXT,
ADD COLUMN categories TEXT[] DEFAULT '{}' NOT NULL;

-- Create an index on is_favorite for faster filtering of favorite quotes
CREATE INDEX idx_quotes_is_favorite ON quotes(user_id, is_favorite) WHERE
is_favorite = TRUE;

-- Create an index on categories for faster filtering by category
CREATE INDEX idx_quotes_categories ON quotes USING GIN(categories);
```

#### For account delete
```sql
-- Function to allow users to delete their own account
-- Run this in your Supabase SQL Editor

-- This function allows authenticated users to delete their own account
CREATE OR REPLACE FUNCTION delete_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id uuid;
BEGIN
  -- Get the current user's ID
  user_id := auth.uid();

  -- Check if user is authenticated
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete the user from auth.users
  -- This will cascade delete related records if CASCADE is set up
  DELETE FROM auth.users WHERE id = user_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user() TO authenticated;

-- Optional: Add a comment to document the function
COMMENT ON FUNCTION delete_user() IS 'Allows authenticated users to delete their own account and all associated data';

```

## 6- Verify all the Apple Bundle ID and everything and sync them properly.

## 7- Add RLS Policies for Supabase Storage
- Create Bucket 'profile-images'
- Add this check to Supabase storage in new policy

```sql
(bucket_id = 'profile-images'::text) AND ((split_part(name, '/'::text, 1))::uuid = auth.uid())
```
<img width="1185" height="814" alt="Screenshot 2025-12-02 at 22 38 20" src="https://github.com/user-attachments/assets/1231e589-227f-4bac-a65f-e4578d189959" />


## 8- Landing Page (starter kit)
 - [Get the Repo](https://github.com/proSamik/ios-app-landing-page)
---

## Issues?

If you have any issues, ask doubt [here](https://github.com/proSamik/lighter-starter-kit-ios-app/issues) and tag me as @prosamik so i get notification.
