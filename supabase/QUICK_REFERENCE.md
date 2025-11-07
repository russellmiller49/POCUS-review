# Quick Reference: User Role Management

## ✅ Auto-Assignment Setup (COMPLETE)

New users will automatically get the **'fellow'** role when they sign up, assigned to the default institution.

## 🔧 Manual Promotion

### Promote User by Email
```sql
UPDATE public.memberships
SET role = 'admin'  -- or 'attending'
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'user@example.com')
AND institution_id = (SELECT id FROM public.institutions WHERE slug = 'default-institution');
```

### Promote User by User ID
```sql
UPDATE public.memberships
SET role = 'admin'
WHERE user_id = 'USER_ID'::uuid
AND institution_id = 'INSTITUTION_ID'::uuid;
```

## 📋 Check User Roles
```sql
SELECT 
    u.email,
    i.name as institution,
    m.role,
    m.created_at
FROM public.memberships m
JOIN auth.users u ON u.id = m.user_id
JOIN public.institutions i ON i.id = m.institution_id
WHERE u.email = 'user@example.com';
```

## 🆕 Add Role to New User (Manual)
```sql
INSERT INTO public.memberships (user_id, institution_id, role)
SELECT 
    u.id,
    i.id,
    'fellow'  -- or 'attending' or 'admin'
FROM auth.users u
CROSS JOIN public.institutions i
WHERE u.email = 'newuser@example.com'
  AND i.slug = 'default-institution'
ON CONFLICT (user_id, institution_id) DO NOTHING;
```

## 📁 Files Available
- `assign_user_roles.md` - Complete guide
- `promote_user.sql` - Promotion scripts
- `add_user_role.sql` - Manual role assignment
- `quick_assign_role.sql` - Quick reference script



