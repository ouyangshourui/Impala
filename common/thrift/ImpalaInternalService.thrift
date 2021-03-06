// Copyright 2012 Cloudera Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
// This file contains the details of the protocol between coordinators and backends.

namespace cpp impala
namespace java com.cloudera.impala.thrift

include "Status.thrift"
include "ErrorCodes.thrift"
include "Types.thrift"
include "Exprs.thrift"
include "CatalogObjects.thrift"
include "Descriptors.thrift"
include "PlanNodes.thrift"
include "Planner.thrift"
include "DataSinks.thrift"
include "Results.thrift"
include "RuntimeProfile.thrift"
include "ImpalaService.thrift"
include "Llama.thrift"

// constants for TQueryOptions.num_nodes
const i32 NUM_NODES_ALL = 0
const i32 NUM_NODES_ALL_RACKS = -1

// constants for TPlanNodeId
const i32 INVALID_PLAN_NODE_ID = -1

// Constant default partition ID, must be < 0 to avoid collisions
const i64 DEFAULT_PARTITION_ID = -1;

enum TParquetFallbackSchemaResolution {
  POSITION,
  NAME
}

// Query options that correspond to ImpalaService.ImpalaQueryOptions, with their
// respective defaults. Query options can be set in the following ways:
//
// 1) Process-wide defaults (via the impalad arg --default_query_options)
// 2) Resource pool defaults (via resource pool configuration)
// 3) Session settings (via the SET command or the HS2 OpenSession RPC)
// 4) HS2/Beeswax configuration 'overlay' in the request metadata
//
// (1) and (2) are set by administrators and provide the default query options for a
// session, in that order, so options set in (2) override those in (1). The user
// can specify query options with (3) to override the defaults, which are stored in the
// SessionState. Finally, the client can pass a config 'overlay' (4) in the request
// metadata which overrides everything else.
struct TQueryOptions {
  1: optional bool abort_on_error = 0
  2: optional i32 max_errors = 0
  3: optional bool disable_codegen = 0
  4: optional i32 batch_size = 0
  5: optional i32 num_nodes = NUM_NODES_ALL
  6: optional i64 max_scan_range_length = 0
  7: optional i32 num_scanner_threads = 0

  8: optional i32 max_io_buffers = 0              // Deprecated in 1.1
  9: optional bool allow_unsupported_formats = 0
  10: optional i64 default_order_by_limit = -1    // Deprecated in 1.4
  11: optional string debug_action = ""
  12: optional i64 mem_limit = 0
  13: optional bool abort_on_default_limit_exceeded = 0 // Deprecated in 1.4
  14: optional CatalogObjects.THdfsCompression compression_codec
  15: optional i32 hbase_caching = 0
  16: optional bool hbase_cache_blocks = 0
  17: optional i64 parquet_file_size = 0
  18: optional Types.TExplainLevel explain_level = 1
  19: optional bool sync_ddl = 0

  // Request pool this request should be submitted to. If not set
  // the pool is determined based on the user.
  20: optional string request_pool

  // Per-host virtual CPU cores required for query (only relevant with RM).
  21: optional i16 v_cpu_cores

  // Max time in milliseconds the resource broker should wait for
  // a resource request to be granted by Llama/Yarn (only relevant with RM).
  22: optional i64 reservation_request_timeout

  // Disables taking advantage of HDFS caching. This has two parts:
  // 1. disable preferring to schedule to cached replicas
  // 2. disable the cached read path.
  23: optional bool disable_cached_reads = 0

  // test hook to disable topn on the outermost select block.
  24: optional bool disable_outermost_topn = 0

  // Override for initial memory reservation size if RM is enabled.
  25: optional i64 rm_initial_mem = 0

  // Time, in s, before a query will be timed out if it is inactive. May not exceed
  // --idle_query_timeout if that flag > 0.
  26: optional i32 query_timeout_s = 0

  // test hook to cap max memory for spilling operators (to force them to spill).
  27: optional i64 max_block_mgr_memory

  // If true, transforms all count(distinct) aggregations into NDV()
  28: optional bool appx_count_distinct = 0

  // If true, allows Impala to internally disable spilling for potentially
  // disastrous query plans. Impala will excercise this option if a query
  // has no plan hints, and at least one table is missing relevant stats.
  29: optional bool disable_unsafe_spills = 0

  // Mode for compression; RECORD, or BLOCK
  // This field only applies for certain file types and is ignored
  // by all other file types.
  30: optional CatalogObjects.THdfsSeqCompressionMode seq_compression_mode

  // If the number of rows that are processed for a single query is below the
  // threshold, it will be executed on the coordinator only with codegen disabled
  31: optional i32 exec_single_node_rows_threshold = 100

  // If true, use the table's metadata to produce the partition columns instead of table
  // scans whenever possible. This option is opt-in by default as this optimization may
  // produce different results than the scan based approach in some edge cases.
  32: optional bool optimize_partition_key_scans = 0

  // Specify the prefered locality level of replicas during scan scheduling.
  // Replicas with an equal or better locality will be preferred.
  33: optional PlanNodes.TReplicaPreference replica_preference =
      PlanNodes.TReplicaPreference.CACHE_LOCAL

  // Configure whether scan ranges with local replicas will be assigned by starting from
  // the same replica for every query or by starting with a new, pseudo-random replica for
  // subsequent queries. The default is to start with the same replica for every query.
  34: optional bool schedule_random_replica = 0

  // For scan nodes with any conjuncts, use codegen to evaluate the conjuncts if
  // the number of rows * number of operators in the conjuncts exceeds this threshold.
  35: optional i64 scan_node_codegen_threshold = 1800000

  // If true, the planner will not generate plans with streaming preaggregations.
  36: optional bool disable_streaming_preaggregations = 0

  // If true, runtime filter propagation is enabled
  37: optional Types.TRuntimeFilterMode runtime_filter_mode = 2

  // Size in bytes of Bloom Filters used for runtime filters. Actual size of filter will
  // be rounded up to the nearest power of two.
  38: optional i32 runtime_bloom_filter_size = 1048576

  // Time in ms to wait until partition filters are delivered. If 0, the default defined
  // by the startup flag of the same name is used.
  39: optional i32 runtime_filter_wait_time_ms = 0

  // If true, per-row runtime filtering is disabled
  40: optional bool disable_row_runtime_filtering = false

  // Maximum number of runtime filters allowed per query
  41: optional i32 max_num_runtime_filters = 10

  // If true, use UTF-8 annotation for string columns. Note that char and varchar columns
  // always use the annotation.
  //
  // This is disabled by default in order to preserve the existing behavior of legacy
  // workloads. In addition, Impala strings are not necessarily UTF8-encoded.
  42: optional bool parquet_annotate_strings_utf8 = false

  // Determines how to resolve Parquet files' schemas in the absence of field IDs (which
  // is always, since fields IDs are NYI). Valid values are "position" (default) and
  // "name".
  43: optional TParquetFallbackSchemaResolution parquet_fallback_schema_resolution = 0

  // Multi-threaded execution: number of cores per query per node.
  // > 1: multi-threaded execution mode, with given number of cores
  // 1: single-threaded execution mode
  // 0: multi-threaded execution mode, number of cores is the pool default
  44: optional i32 mt_num_cores = 1

  // If true, INSERT writes to S3 go directly to their final location rather than being
  // copied there by the coordinator. We cannot do this for INSERT OVERWRITES because for
  // those queries, the coordinator deletes all files in the final location before copying
  // the files there.
  45: optional bool s3_skip_insert_staging = true

  // Minimum runtime filter size, in bytes
  46: optional i32 runtime_filter_min_size = 1048576

  // Maximum runtime filter size, in bytes
  47: optional i32 runtime_filter_max_size = 16777216

  // Prefetching behavior during hash tables' building and probing.
  48: optional Types.TPrefetchMode prefetch_mode = Types.TPrefetchMode.HT_BUCKET

  // Additional strict handling of invalid data parsing and type conversions.
  49: optional bool strict_mode = false
}

// Impala currently has two types of sessions: Beeswax and HiveServer2
enum TSessionType {
  BEESWAX,
  HIVESERVER2
}

// Per-client session state
struct TSessionState {
  // A unique identifier for this session
  3: required Types.TUniqueId session_id

  // Session Type (Beeswax or HiveServer2)
  5: required TSessionType session_type

  // The default database for the session
  1: required string database

  // The user to whom this session belongs
  2: required string connected_user

  // If set, the user we are delegating for the current session
  6: optional string delegated_user;

  // Client network address
  4: required Types.TNetworkAddress network_address
}

// Client request including stmt to execute and query options.
struct TClientRequest {
  // SQL stmt to be executed
  1: required string stmt

  // query options
  2: required TQueryOptions query_options

  // Redacted SQL stmt
  3: optional string redacted_stmt
}

// Context of this query, including the client request, session state and
// global query parameters needed for consistent expr evaluation (e.g., now()).
// TODO: Separate into FE/BE initialized vars.
struct TQueryCtx {
  // Client request containing stmt to execute and query options.
  1: required TClientRequest request

  // A globally unique id assigned to the entire query in the BE.
  2: required Types.TUniqueId query_id

  // Session state including user.
  3: required TSessionState session

  // String containing a timestamp set as the query submission time.
  4: required string now_string

  // Process ID of the impalad to which the user is connected.
  5: required i32 pid

  // Initiating coordinator.
  // TODO: determine whether we can get this somehow via the Thrift rpc mechanism.
  6: optional Types.TNetworkAddress coord_address

  // List of tables missing relevant table and/or column stats. Used for
  // populating query-profile fields consumed by CM as well as warning messages.
  7: optional list<CatalogObjects.TTableName> tables_missing_stats

  // Internal flag to disable spilling. Used as a guard against potentially
  // disastrous query plans. The rationale is that cancelling queries, e.g.,
  // with a huge join build is preferable over spilling "forever".
  8: optional bool disable_spilling

  // Set if this is a child query (e.g. a child of a COMPUTE STATS request)
  9: optional Types.TUniqueId parent_query_id

  // List of tables suspected to have corrupt stats
  10: optional list<CatalogObjects.TTableName> tables_with_corrupt_stats

  // The snapshot timestamp as of which to execute the query
  // When the backing storage engine supports snapshot timestamps (such as Kudu) this
  // allows to select a snapshot timestamp on which to perform the scan, making sure that
  // results returned from multiple scan nodes are consistent.
  // This defaults to -1 when no timestamp is specified.
  11: optional i64 snapshot_timestamp = -1;

  // Contains only the union of those descriptors referenced by list of fragments destined
  // for a single host. Optional for frontend tests.
  12: optional Descriptors.TDescriptorTable desc_tbl
}

// Context to collect information, which is shared among all instances of that plan
// fragment.
struct TPlanFragmentCtx {
  1: required Planner.TPlanFragment fragment

  // total number of instances of this fragment
  2: required i32 num_fragment_instances
}

// A scan range plus the parameters needed to execute that scan.
struct TScanRangeParams {
  1: required PlanNodes.TScanRange scan_range
  2: optional i32 volume_id = -1
  3: optional bool is_cached = false
  4: optional bool is_remote
}

// Specification of one output destination of a plan fragment
struct TPlanFragmentDestination {
  // the globally unique fragment instance id
  1: required Types.TUniqueId fragment_instance_id

  // ... which is being executed on this server
  2: required Types.TNetworkAddress server
}

// Execution parameters of a fragment instance, including its unique id, the total number
// of fragment instances, the query context, the coordinator address, etc.
// TODO: for range partitioning, we also need to specify the range boundaries
struct TPlanFragmentInstanceCtx {
  // the globally unique fragment instance id
  1: required Types.TUniqueId fragment_instance_id

  // Index of this fragment instance accross all instances of its parent fragment,
  // range [0, TPlanFragmentCtx.num_fragment_instances).
  2: required i32 fragment_instance_idx

  // Index of this fragment instance in Coordinator::fragment_instance_states_.
  3: required i32 instance_state_idx

  // Initial scan ranges for each scan node in TPlanFragment.plan_tree
  4: required map<Types.TPlanNodeId, list<TScanRangeParams>> per_node_scan_ranges

  // Number of senders for ExchangeNodes contained in TPlanFragment.plan_tree;
  // needed to create a DataStreamRecvr
  5: required map<Types.TPlanNodeId, i32> per_exch_num_senders

  // Output destinations, one per output partition.
  // The partitioning of the output is specified by
  // TPlanFragment.output_sink.output_partition.
  // The number of output partitions is destinations.size().
  6: list<TPlanFragmentDestination> destinations

  // Debug options: perform some action in a particular phase of a particular node
  7: optional Types.TPlanNodeId debug_node_id
  8: optional PlanNodes.TExecNodePhase debug_phase
  9: optional PlanNodes.TDebugAction debug_action

  // The pool to which this request has been submitted. Used to update pool statistics
  // for admission control.
  10: optional string request_pool

  // Id of this fragment in its role as a sender.
  11: optional i32 sender_id

  // Resource reservation to run this plan fragment in.
  12: optional Llama.TAllocatedResource reserved_resource

  // Address of local node manager (used for expanding resource allocations)
  13: optional Types.TNetworkAddress local_resource_address
}


// Service Protocol Details

enum ImpalaInternalServiceVersion {
  V1
}


// ExecPlanFragment

struct TExecPlanFragmentParams {
  1: required ImpalaInternalServiceVersion protocol_version

  // Context of the query, which this fragment is part of.
  2: optional TQueryCtx query_ctx

  // Context of this fragment.
  3: optional TPlanFragmentCtx fragment_ctx

  // Context of this fragment instance, including its instance id, the total number
  // fragment instances, the query context, etc.
  4: optional TPlanFragmentInstanceCtx fragment_instance_ctx
}

struct TExecPlanFragmentResult {
  // required in V1
  1: optional Status.TStatus status
}

// ReportExecStatus
struct TParquetInsertStats {
  // For each column, the on disk byte size
  1: required map<string, i64> per_column_size
}

// Per partition insert stats
// TODO: this should include the table stats that we update the metastore with.
struct TInsertStats {
  1: required i64 bytes_written
  2: optional TParquetInsertStats parquet_stats
}

const string ROOT_PARTITION_KEY = ''

// Per-partition statistics and metadata resulting from INSERT queries.
struct TInsertPartitionStatus {
  // The id of the partition written to (may be -1 if the partition is created by this
  // query). See THdfsTable.partitions.
  1: optional i64 id

  // The number of rows appended to this partition
  2: optional i64 num_appended_rows

  // Detailed statistics gathered by table writers for this partition
  3: optional TInsertStats stats

  // Fully qualified URI to the base directory for this partition.
  4: required string partition_base_dir
}

// The results of an INSERT query, sent to the coordinator as part of
// TReportExecStatusParams
struct TInsertExecStatus {
  // A map from temporary absolute file path to final absolute destination. The
  // coordinator performs these updates after the query completes.
  1: required map<string, string> files_to_move;

  // Per-partition details, used in finalization and reporting.
  // The keys represent partitions to create, coded as k1=v1/k2=v2/k3=v3..., with the
  // root's key in an unpartitioned table being ROOT_PARTITION_KEY.
  // The target table name is recorded in the corresponding TQueryExecRequest
  2: optional map<string, TInsertPartitionStatus> per_partition_status
}

// Error message exchange format
struct TErrorLogEntry {

  // Number of error messages reported using the above identifier
  1: i32 count = 0

  // Sample messages from the above error code
  2: list<string> messages
}

struct TReportExecStatusParams {
  1: required ImpalaInternalServiceVersion protocol_version

  // required in V1
  2: optional Types.TUniqueId query_id

  // required in V1
  // Used to look up the fragment instance state in the coordinator, same value as
  // TExecPlanFragmentParams.instance_state_idx.
  3: optional i32 instance_state_idx

  // required in V1
  4: optional Types.TUniqueId fragment_instance_id

  // Status of fragment execution; any error status means it's done.
  // required in V1
  5: optional Status.TStatus status

  // If true, fragment finished executing.
  // required in V1
  6: optional bool done

  // cumulative profile
  // required in V1
  7: optional RuntimeProfile.TRuntimeProfileTree profile

  // Cumulative structural changes made by a table sink
  // optional in V1
  8: optional TInsertExecStatus insert_exec_status;

  // New errors that have not been reported to the coordinator
  9: optional map<ErrorCodes.TErrorCode, TErrorLogEntry> error_log;
}

struct TReportExecStatusResult {
  // required in V1
  1: optional Status.TStatus status
}


// CancelPlanFragment

struct TCancelPlanFragmentParams {
  1: required ImpalaInternalServiceVersion protocol_version

  // required in V1
  2: optional Types.TUniqueId fragment_instance_id
}

struct TCancelPlanFragmentResult {
  // required in V1
  1: optional Status.TStatus status
}


// TransmitData

struct TTransmitDataParams {
  1: required ImpalaInternalServiceVersion protocol_version

  // required in V1
  2: optional Types.TUniqueId dest_fragment_instance_id

  // Id of this fragment in its role as a sender.
  3: optional i32 sender_id

  // required in V1
  4: optional Types.TPlanNodeId dest_node_id

  // required in V1
  5: optional Results.TRowBatch row_batch

  // if set to true, indicates that no more row batches will be sent
  // for this dest_node_id
  6: optional bool eos
}

struct TTransmitDataResult {
  // required in V1
  1: optional Status.TStatus status
}

// Parameters for RequestPoolService.resolveRequestPool()
struct TResolveRequestPoolParams {
  // User to resolve to a pool via the allocation placement policy and
  // authorize for pool access.
  1: required string user

  // Pool name specified by the user. The allocation placement policy may
  // return a different pool.
  2: required string requested_pool
}

// Returned by RequestPoolService.resolveRequestPool()
struct TResolveRequestPoolResult {
  // Actual pool to use, as determined by the pool allocation policy. Not set
  // if no pool was resolved.
  1: optional string resolved_pool

  // True if the user has access to submit requests to the resolved_pool. Not set
  // if no pool was resolved.
  2: optional bool has_access

  3: optional Status.TStatus status
}

// Parameters for RequestPoolService.getPoolConfig()
struct TPoolConfigParams {
  // Pool name
  1: required string pool
}

// Returned by RequestPoolService.getPoolConfig()
struct TPoolConfig {
  // Maximum number of placed requests before incoming requests are queued.
  // A value of 0 effectively disables the pool. -1 indicates no limit.
  1: required i64 max_requests

  // Maximum number of queued requests before incoming requests are rejected.
  // Any non-positive number (<= 0) disables queuing, i.e. requests are rejected instead
  // of queued.
  2: required i64 max_queued

  // Maximum memory resources of the pool in bytes.
  // A value of 0 effectively disables the pool. -1 indicates no limit.
  3: required i64 max_mem_resources

  // Maximum amount of time (in milliseconds) that a request will wait to be admitted
  // before timing out. Optional, if not set then the process default (set via gflags) is
  // used.
  4: optional i64 queue_timeout_ms;

  // Default query options that are applied to requests mapped to this pool.
  5: required string default_query_options;
}

struct TBloomFilter {
  // Log_2 of the heap space required for this filter. See BloomFilter::BloomFilter() for
  // details.
  1: required i32 log_heap_space

  // List of buckets representing the Bloom Filter contents, laid out contiguously in one
  // string for efficiency of (de)serialisation. See BloomFilter::Bucket and
  // BloomFilter::directory_.
  2: binary directory

  // If true, this filter allows all elements to pass (i.e. its selectivity is 1). If
  // true, 'directory' and 'log_heap_space' are not meaningful.
  4: required bool always_true
}

struct TUpdateFilterResult {

}

struct TUpdateFilterParams {
  // Filter ID, unique within a query.
  1: required i32 filter_id

  // Query that this filter is for.
  2: required Types.TUniqueId query_id

  3: required TBloomFilter bloom_filter
}

struct TPublishFilterResult {

}

struct TPublishFilterParams {
  // Filter ID to update
  1: required i32 filter_id

  // ID of fragment to receive this filter
  2: required Types.TUniqueId dst_instance_id

  // Actual bloom_filter payload
  3: required TBloomFilter bloom_filter
}

service ImpalaInternalService {
  // Called by coord to start asynchronous execution of plan fragment in backend.
  // Returns as soon as all incoming data streams have been set up.
  TExecPlanFragmentResult ExecPlanFragment(1:TExecPlanFragmentParams params);

  // Periodically called by backend to report status of plan fragment execution
  // back to coord; also called when execution is finished, for whatever reason.
  TReportExecStatusResult ReportExecStatus(1:TReportExecStatusParams params);

  // Called by coord to cancel execution of a single plan fragment, which this
  // coordinator initiated with a prior call to ExecPlanFragment.
  // Cancellation is asynchronous.
  TCancelPlanFragmentResult CancelPlanFragment(1:TCancelPlanFragmentParams params);

  // Called by sender to transmit single row batch. Returns error indication
  // if params.fragmentId or params.destNodeId are unknown or if data couldn't be read.
  TTransmitDataResult TransmitData(1:TTransmitDataParams params);

  // Called by fragment instances that produce local runtime filters to deliver them to
  // the coordinator for aggregation and broadcast.
  TUpdateFilterResult UpdateFilter(1:TUpdateFilterParams params);

  // Called by the coordinator to deliver global runtime filters to fragment instances for
  // application at plan nodes.
  TPublishFilterResult PublishFilter(1:TPublishFilterParams params);
}
