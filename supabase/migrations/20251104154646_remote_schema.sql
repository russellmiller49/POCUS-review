


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


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name',''))
  on conflict (id) do nothing;
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_member_of"("inst_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid() and m.institution_id = inst_id
  );
$$;


ALTER FUNCTION "public"."is_member_of"("inst_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."audit_events" (
    "id" bigint NOT NULL,
    "user_id" "uuid",
    "action" "text" NOT NULL,
    "entity" "text" NOT NULL,
    "entity_id" "uuid",
    "ip" "inet",
    "ua" "text",
    "at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_events" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."audit_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."audit_events_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."audit_events_id_seq" OWNED BY "public"."audit_events"."id";



CREATE TABLE IF NOT EXISTS "public"."feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "study_id" "uuid" NOT NULL,
    "reviewer_id" "uuid" NOT NULL,
    "rating" integer,
    "comments" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "feedback_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."institutions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "slug" "text" NOT NULL,
    "name" "text" NOT NULL,
    "settings" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."institutions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."media" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "study_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "storage_path" "text" NOT NULL,
    "content_type" "text" NOT NULL,
    "duration_sec" numeric,
    "width" integer,
    "height" integer,
    "sha256" "text",
    "status" "text" DEFAULT 'clean'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "media_kind_check" CHECK (("kind" = ANY (ARRAY['image'::"text", 'video'::"text", 'dicom'::"text", 'other'::"text"]))),
    CONSTRAINT "media_status_check" CHECK (("status" = ANY (ARRAY['clean'::"text", 'error'::"text"])))
);


ALTER TABLE "public"."media" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."memberships" (
    "user_id" "uuid" NOT NULL,
    "institution_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "roles" "text"[],
    CONSTRAINT "memberships_role_check" CHECK (("role" = ANY (ARRAY['fellow'::"text", 'attending'::"text", 'admin'::"text"]))),
    CONSTRAINT "memberships_roles_allowed" CHECK ((("roles" <@ ARRAY['fellow'::"text", 'attending'::"text", 'admin'::"text"]) AND ("array_length"("roles", 1) >= 1)))
);


ALTER TABLE "public"."memberships" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text",
    "default_institution" "uuid"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."signoffs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "study_id" "uuid" NOT NULL,
    "attending_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "signed_at" timestamp with time zone,
    CONSTRAINT "signoffs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'revisions'::"text"])))
);


ALTER TABLE "public"."signoffs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."studies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "institution_id" "uuid" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "exam_type" "text" NOT NULL,
    "status" "text" NOT NULL,
    "submitted_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "studies_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'submitted'::"text", 'reviewable'::"text", 'signed_off'::"text"])))
);


ALTER TABLE "public"."studies" OWNER TO "postgres";


ALTER TABLE ONLY "public"."audit_events" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."audit_events_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."institutions"
    ADD CONSTRAINT "institutions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."institutions"
    ADD CONSTRAINT "institutions_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."media"
    ADD CONSTRAINT "media_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_pkey" PRIMARY KEY ("user_id", "institution_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."signoffs"
    ADD CONSTRAINT "signoffs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."studies"
    ADD CONSTRAINT "studies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_reviewer_id_fkey" FOREIGN KEY ("reviewer_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_study_id_fkey" FOREIGN KEY ("study_id") REFERENCES "public"."studies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."media"
    ADD CONSTRAINT "media_study_id_fkey" FOREIGN KEY ("study_id") REFERENCES "public"."studies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "public"."institutions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_default_institution_fkey" FOREIGN KEY ("default_institution") REFERENCES "public"."institutions"("id");



ALTER TABLE ONLY "public"."signoffs"
    ADD CONSTRAINT "signoffs_attending_id_fkey" FOREIGN KEY ("attending_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."signoffs"
    ADD CONSTRAINT "signoffs_study_id_fkey" FOREIGN KEY ("study_id") REFERENCES "public"."studies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."studies"
    ADD CONSTRAINT "studies_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."studies"
    ADD CONSTRAINT "studies_institution_id_fkey" FOREIGN KEY ("institution_id") REFERENCES "public"."institutions"("id") ON DELETE CASCADE;



ALTER TABLE "public"."audit_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feedback" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ins_audit" ON "public"."audit_events" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "ins_feedback" ON "public"."feedback" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."studies" "s"
     JOIN "public"."memberships" "m" ON ((("m"."institution_id" = "s"."institution_id") AND ("m"."user_id" = "auth"."uid"()))))
  WHERE (("s"."id" = "feedback"."study_id") AND ("m"."role" = ANY (ARRAY['attending'::"text", 'admin'::"text"]))))));



CREATE POLICY "ins_media" ON "public"."media" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."studies" "s"
  WHERE (("s"."id" = "media"."study_id") AND ("s"."created_by" = "auth"."uid"())))));



CREATE POLICY "ins_signoffs" ON "public"."signoffs" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."studies" "s"
     JOIN "public"."memberships" "m" ON ((("m"."institution_id" = "s"."institution_id") AND ("m"."user_id" = "auth"."uid"()))))
  WHERE (("s"."id" = "signoffs"."study_id") AND ("m"."role" = ANY (ARRAY['attending'::"text", 'admin'::"text"]))))));



CREATE POLICY "ins_studies" ON "public"."studies" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_member_of"("institution_id") AND ("created_by" = "auth"."uid"())));



ALTER TABLE "public"."institutions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."media" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."memberships" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sel_audit_self" ON "public"."audit_events" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "sel_feedback" ON "public"."feedback" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."studies" "s"
  WHERE (("s"."id" = "feedback"."study_id") AND "public"."is_member_of"("s"."institution_id")))));



CREATE POLICY "sel_inst" ON "public"."institutions" FOR SELECT TO "authenticated" USING ("public"."is_member_of"("id"));



CREATE POLICY "sel_media" ON "public"."media" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."studies" "s"
  WHERE (("s"."id" = "media"."study_id") AND "public"."is_member_of"("s"."institution_id")))));



CREATE POLICY "sel_memberships_self" ON "public"."memberships" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "sel_profiles_self" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("id" = "auth"."uid"()));



CREATE POLICY "sel_signoffs" ON "public"."signoffs" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."studies" "s"
  WHERE (("s"."id" = "signoffs"."study_id") AND "public"."is_member_of"("s"."institution_id")))));



CREATE POLICY "sel_studies" ON "public"."studies" FOR SELECT TO "authenticated" USING ("public"."is_member_of"("institution_id"));



ALTER TABLE "public"."signoffs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."studies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "upd_studies" ON "public"."studies" FOR UPDATE TO "authenticated" USING (("public"."is_member_of"("institution_id") AND (("created_by" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."user_id" = "auth"."uid"()) AND ("m"."institution_id" = "studies"."institution_id") AND ("m"."role" = ANY (ARRAY['attending'::"text", 'admin'::"text"]))))))));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_member_of"("inst_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_member_of"("inst_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_member_of"("inst_id" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."audit_events" TO "anon";
GRANT ALL ON TABLE "public"."audit_events" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_events" TO "service_role";



GRANT ALL ON SEQUENCE "public"."audit_events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."audit_events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."audit_events_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."feedback" TO "anon";
GRANT ALL ON TABLE "public"."feedback" TO "authenticated";
GRANT ALL ON TABLE "public"."feedback" TO "service_role";



GRANT ALL ON TABLE "public"."institutions" TO "anon";
GRANT ALL ON TABLE "public"."institutions" TO "authenticated";
GRANT ALL ON TABLE "public"."institutions" TO "service_role";



GRANT ALL ON TABLE "public"."media" TO "anon";
GRANT ALL ON TABLE "public"."media" TO "authenticated";
GRANT ALL ON TABLE "public"."media" TO "service_role";



GRANT ALL ON TABLE "public"."memberships" TO "anon";
GRANT ALL ON TABLE "public"."memberships" TO "authenticated";
GRANT ALL ON TABLE "public"."memberships" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."signoffs" TO "anon";
GRANT ALL ON TABLE "public"."signoffs" TO "authenticated";
GRANT ALL ON TABLE "public"."signoffs" TO "service_role";



GRANT ALL ON TABLE "public"."studies" TO "anon";
GRANT ALL ON TABLE "public"."studies" TO "authenticated";
GRANT ALL ON TABLE "public"."studies" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


  create policy "storage_insert"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'pocus-media'::text) AND (EXISTS ( SELECT 1
   FROM public.studies s
  WHERE ((POSITION(((((('studies/'::text || (s.institution_id)::text) || '/'::text) || (s.id)::text) || '/'::text)) IN (objects.name)) = 1) AND (s.created_by = auth.uid()))))));



  create policy "storage_select"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'pocus-media'::text) AND (EXISTS ( SELECT 1
   FROM public.studies s
  WHERE ((POSITION(((((('studies/'::text || (s.institution_id)::text) || '/'::text) || (s.id)::text) || '/'::text)) IN (objects.name)) = 1) AND public.is_member_of(s.institution_id))))));



  create policy "storage_update"
  on "storage"."objects"
  as permissive
  for update
  to authenticated
using (((bucket_id = 'pocus-media'::text) AND (EXISTS ( SELECT 1
   FROM (public.studies s
     JOIN public.memberships m ON (((m.institution_id = s.institution_id) AND (m.user_id = auth.uid()))))
  WHERE ((POSITION(((((('studies/'::text || (s.institution_id)::text) || '/'::text) || (s.id)::text) || '/'::text)) IN (objects.name)) = 1) AND ((s.created_by = auth.uid()) OR (m.role = ANY (ARRAY['attending'::text, 'admin'::text]))))))));



