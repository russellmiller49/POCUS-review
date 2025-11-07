# How to Assign User Roles to New Users

## Overview

User roles are managed through the `memberships` table, which links users to institutions with specific roles. Each user can have different roles in different institutions (multi-tenant support).

## Available Roles

- **`fellow`** - Can create and manage studies
- **`attending`** - Can review studies and provide feedback
- **`admin`** - Full access, can manage everything

## Methods to Assign Roles

### Method 1: Manual SQL (Supabase Dashboard)

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Run one of the scripts below

#### For a Single User (by Email)

```sql
-- Step 1: Find the user's ID by email
SELECT id, email FROM auth.users WHERE email = 'user@example.com';

-- Step 2: Get institution ID
SELECT id, slug, name FROM public.institutions;

-- Step 3: Assign role (replace UUIDs with actual values)
INSERT INTO public.memberships (user_id, institution_id, role)
VALUES (
    'USER_ID_FROM_STEP_1'::uuid,
    'INSTITUTION_ID_FROM_STEP_2'::uuid,
    'fellow'  -- or 'attending' or 'admin'
)
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET role = EXCLUDED.role
RETURNING *;
```

#### For a Single User (by User ID)

```sql
-- If you already know the user ID
INSERT INTO public.memberships (user_id, institution_id, role)
SELECT 
    'c0afbb5e-bf22-46d1-b77a-bf4df38a1d81'::uuid,  -- User ID
    i.id,                                           -- Institution ID
    'admin'                                         -- Role
FROM public.institutions i
WHERE i.slug = 'default-institution'  -- or use specific institution
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET role = EXCLUDED.role;
```

#### Bulk Assignment (Multiple Users)

```sql
-- Assign multiple users to an institution
INSERT INTO public.memberships (user_id, institution_id, role)
SELECT 
    u.id,
    i.id,
    CASE 
        WHEN u.email LIKE '%@example.com' THEN 'fellow'
        WHEN u.email LIKE '%@admin.com' THEN 'admin'
        ELSE 'attending'
    END as role
FROM auth.users u
CROSS JOIN public.institutions i
WHERE i.slug = 'default-institution'
  AND u.email IN ('user1@example.com', 'user2@example.com', 'user3@example.com')
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET role = EXCLUDED.role;
```

### Method 2: Using Supabase Dashboard Table Editor

1. Go to **Supabase Dashboard** → **Table Editor** → **memberships**
2. Click **Insert** → **Insert row**
3. Fill in:
   - `user_id`: The UUID from `auth.users` table
   - `institution_id`: The UUID from `institutions` table
   - `role`: `'fellow'`, `'attending'`, or `'admin'`
4. Click **Save**

### Method 3: Automatic Assignment via Database Trigger (Advanced)

Create a trigger that automatically assigns roles when users sign up:

```sql
-- Create function to auto-assign default role
CREATE OR REPLACE FUNCTION public.assign_default_role()
RETURNS TRIGGER AS $$
DECLARE
    default_institution_id uuid;
BEGIN
    -- Get the first/default institution
    SELECT id INTO default_institution_id 
    FROM public.institutions 
    ORDER BY created_at ASC 
    LIMIT 1;
    
    -- Assign 'fellow' role by default (or change to 'attending' or 'admin')
    IF default_institution_id IS NOT NULL THEN
        INSERT INTO public.memberships (user_id, institution_id, role)
        VALUES (NEW.id, default_institution_id, 'fellow')
        ON CONFLICT (user_id, institution_id) DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger (runs after profile is created)
CREATE TRIGGER assign_default_role_trigger
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.assign_default_role();
```

### Method 4: Via Your Swift App (Programmatic)

You can create an admin function in your app to assign roles:

```swift
// Example: Admin function to assign roles
func assignRole(userId: UUID, institutionId: UUID, role: String) async throws {
    let payload = [
        "user_id": userId.uuidString,
        "institution_id": institutionId.uuidString,
        "role": role
    ]
    
    try await client
        .from("memberships")
        .upsert(payload, onConflict: "user_id,institution_id")
        .execute()
}
```

## Common Scenarios

### Scenario 1: New User Signs Up

**Option A: Manual Assignment**
```sql
-- After user signs up, assign them a role
INSERT INTO public.memberships (user_id, institution_id, role)
SELECT 
    u.id,
    i.id,
    'fellow'  -- Default role for new users
FROM auth.users u
CROSS JOIN public.institutions i
WHERE u.email = 'newuser@example.com'
  AND i.slug = 'default-institution'
ON CONFLICT (user_id, institution_id) DO NOTHING;
```

**Option B: Use the auto-assignment trigger** (see Method 3 above)

### Scenario 2: Change Existing User's Role

```sql
-- Update an existing user's role
UPDATE public.memberships
SET role = 'admin'  -- New role
WHERE user_id = 'USER_ID'::uuid
  AND institution_id = 'INSTITUTION_ID'::uuid;
```

### Scenario 3: Assign Multiple Roles to Same User

```sql
-- A user can have different roles in different institutions
INSERT INTO public.memberships (user_id, institution_id, role)
VALUES 
    ('USER_ID'::uuid, 'INSTITUTION_1_ID'::uuid, 'fellow'),
    ('USER_ID'::uuid, 'INSTITUTION_2_ID'::uuid, 'admin')
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET role = EXCLUDED.role;
```

### Scenario 4: Bulk Import from CSV/List

```sql
-- Create a temporary table for bulk import
CREATE TEMP TABLE temp_user_roles (
    email text,
    institution_slug text,
    role text
);

-- Insert your data
INSERT INTO temp_user_roles VALUES
    ('user1@example.com', 'default-institution', 'fellow'),
    ('user2@example.com', 'default-institution', 'attending'),
    ('user3@example.com', 'default-institution', 'admin');

-- Assign roles
INSERT INTO public.memberships (user_id, institution_id, role)
SELECT 
    u.id,
    i.id,
    t.role
FROM temp_user_roles t
JOIN auth.users u ON u.email = t.email
JOIN public.institutions i ON i.slug = t.institution_slug
ON CONFLICT (user_id, institution_id) 
DO UPDATE SET role = EXCLUDED.role;

-- Clean up
DROP TABLE temp_user_roles;
```

## Verification Queries

### Check User's Current Roles

```sql
-- See all roles for a specific user
SELECT 
    m.user_id,
    u.email,
    m.institution_id,
    i.name as institution_name,
    m.role,
    m.roles,
    m.created_at
FROM public.memberships m
JOIN auth.users u ON u.id = m.user_id
JOIN public.institutions i ON i.id = m.institution_id
WHERE m.user_id = 'USER_ID'::uuid;
```

### Check All Users and Their Roles

```sql
-- List all users with their roles
SELECT 
    u.email,
    i.name as institution,
    m.role,
    m.created_at as role_assigned_at
FROM public.memberships m
JOIN auth.users u ON u.id = m.user_id
JOIN public.institutions i ON i.id = m.institution_id
ORDER BY u.email, i.name;
```

### Check Users Without Roles

```sql
-- Find users who don't have any roles assigned
SELECT 
    u.id,
    u.email,
    u.created_at
FROM auth.users u
LEFT JOIN public.memberships m ON m.user_id = u.id
WHERE m.user_id IS NULL;
```

## Best Practices

1. **Always assign roles after user creation** - Users need roles to access the app
2. **Use institution-specific roles** - Remember users can have different roles in different institutions
3. **Set up auto-assignment** - Use triggers for default role assignment to reduce manual work
4. **Verify assignments** - Always check that roles were assigned correctly
5. **Use admin role carefully** - Admin role grants full access, use sparingly

## Troubleshooting

### User can't access app
- Check if they have a membership record: `SELECT * FROM memberships WHERE user_id = 'USER_ID'`
- Verify the role is correct: Should be 'fellow', 'attending', or 'admin'
- Check institution membership: User must be member of the institution they're trying to access

### RLS Policy Errors
- Ensure user has a membership record
- Verify `user_id` matches `auth.uid()` 
- Check that the role matches what the policy expects

