-- Enable PostGIS extension
create extension if not exists postgis schema extensions;

-- Create pujas table
create table public.pujas (
    id uuid default gen_random_uuid() primary key,
    name text not null,
    type text not null check (type in ('mega', 'heritage')),
    location geography(Point, 4326) not null,
    history text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create puja_timings table
create table public.puja_timings (
    id uuid default gen_random_uuid() primary key,
    puja_id uuid references public.pujas(id) on delete cascade not null,
    open_time time not null,
    close_time time not null,
    status text not null check (status in ('open', 'closed', 'closing_soon')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create crowd_reports table
create table public.crowd_reports (
    id uuid default gen_random_uuid() primary key,
    puja_id uuid references public.pujas(id) on delete cascade not null,
    status text not null check (status in ('fast', 'slow', 'dead_stop')),
    reported_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create facilities table
create table public.facilities (
    id uuid default gen_random_uuid() primary key,
    type text not null check (type in ('toilet', 'water', 'police')),
    location geography(Point, 4326) not null,
    puja_id uuid references public.pujas(id) on delete cascade,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create indexes for spatial queries
create index pujas_location_idx on public.pujas using gist (location);
create index facilities_location_idx on public.facilities using gist (location);
