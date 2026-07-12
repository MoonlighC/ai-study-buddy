import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { createDeleteSubjectHandler } from "./handler.ts";
const url=Deno.env.get("SUPABASE_URL")??"", anon=Deno.env.get("SUPABASE_ANON_KEY")??"", service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"";
serve(async(request)=>{
  if(!url||!anon||!service)return new Response(JSON.stringify({code:"unknown"}),{status:500});
  let admin:SupabaseClient|null=null;
  return createDeleteSubjectHandler({
    async verifyJwt(jwt){const client=createClient(url,anon,{global:{headers:{Authorization:`Bearer ${jwt}`}},auth:{persistSession:false,autoRefreshToken:false}});const {data,error}=await client.auth.getUser(jwt);if(error||!data.user)return null;admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});return data.user.id;},
    async begin(userId,subjectId){const {data,error}=await admin!.rpc("begin_subject_deletion_internal",{p_user_id:userId,p_subject_id:subjectId}).maybeSingle();return error?null:data;},
    async list(bucket,prefix,offset,limit){const {data,error}=await admin!.storage.from(bucket).list(prefix,{offset,limit,sortBy:{column:"name",order:"asc"}});return {names:(data??[]).map((item)=>item.name),error:!!error};},
    async remove(bucket,paths){const {error}=await admin!.storage.from(bucket).remove(paths);return {error:!!error};},
    async mark(userId,subjectId,stage,code,found,removed){const {error}=await admin!.rpc("mark_subject_deletion_internal",{p_user_id:userId,p_subject_id:subjectId,p_stage:stage,p_safe_error_code:code,p_found:found,p_removed:removed});return !error;},
    async finalize(userId,subjectId){const {error}=await admin!.rpc("finalize_subject_deletion_internal",{p_user_id:userId,p_subject_id:subjectId});return !error;},
    operationId:()=>crypto.randomUUID(),log:(event)=>console.log(JSON.stringify(event)),
  })(request);
});
