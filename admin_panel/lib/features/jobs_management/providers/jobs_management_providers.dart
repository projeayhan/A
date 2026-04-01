import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== COMPANY JOBS ====================

final companyJobsProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String companyId, String? status})>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);
    var query = client
        .from('job_listings')
        .select('*, job_categories(name)')
        .eq('company_id', params.companyId);

    if (params.status != null && params.status != 'all') {
      query = query.eq('status', params.status!);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== JOB APPLICANTS ====================

final jobApplicantsProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String companyId, String? jobId, String? status})>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);
    var query = client
        .from('job_applications')
        .select('*, job_listings(title, company_id)');

    if (params.jobId != null) {
      query = query.eq('listing_id', params.jobId!);
    } else {
      // Filter by poster_id (company owner)
      query = query.eq('poster_id', params.companyId);
    }

    if (params.status != null && params.status != 'all') {
      query = query.eq('status', params.status!);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== COMPANY DETAIL ====================

final companyDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, companyId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('companies')
        .select()
        .eq('id', companyId)
        .maybeSingle();
    return response;
  },
);
