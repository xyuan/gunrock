// -----------------------------------------------------------------------------
// Gunrock -- Fast and Efficient GPU Graph Library
// -----------------------------------------------------------------------------
// This source code is distributed under the terms of LICENSE.TXT
// in the root directory of this source distribution.
// -----------------------------------------------------------------------------

/**
 * @file
 * mst_functor.cuh
 *
 * @brief Device functions for Minimum Spanning Tree problem.
 */

#pragma once

#include <gunrock/app/problem_base.cuh>
#include <gunrock/app/mst/mst_problem.cuh>

namespace gunrock {
namespace app {
namespace mst {

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   find the successor of each vertex / super-vertex
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT = VertexId>
struct SuccFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Forward Advance Kernel condition function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   *
   * \return Whether to load the apply function for the edge and include
   * the destination node in the next frontier.
   */
  static __device__ __forceinline__ bool CondEdge(
    VertexId    s_id,
    VertexId    d_id,
    DataSlice   *d_data_slice,
    SizeT       edge_id,
    VertexId    input_item,
    LabelT      label,
    SizeT       input_pos,
    SizeT       &output_pos)
  {
    // find successors that contribute to the reduced weight value
    return d_data_slice->reduce_val[s_id] == d_data_slice->edge_value[edge_id];
  }

  /**
   * @brief Forward Advance Kernel apply function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   */
  static __device__ __forceinline__ void ApplyEdge(
    VertexId    s_id,
    VertexId    d_id,
    DataSlice   *d_data_slice,
    SizeT       edge_id,
    VertexId    input_item,
    LabelT      label,
    SizeT       input_pos,
    SizeT       &output_pos)
  {
    // select one successor with minimum vertex id
    atomicMin(&d_data_slice->successors[s_id], d_id);
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   find original edge ids for marking MST outputs
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT = VertexId>
struct EdgeFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Forward Advance Kernel condition function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   *
   * \return Whether to load the apply function for the edge and include
   * the destination node in the next frontier.
   */
  static __device__ __forceinline__ bool CondEdge(
    VertexId    s_id,
    VertexId    d_id,
    DataSlice   *d_data_slice,
    SizeT       edge_id,
    VertexId    input_item,
    LabelT      label,
    SizeT       input_pos,
    SizeT       &output_pos)
  {
    return d_data_slice->successors[s_id] == d_id &&
      d_data_slice->reduce_val[s_id] == d_data_slice->edge_value[edge_id];
  }

  /**
   * @brief Forward Advance Kernel apply function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   */
  static __device__ __forceinline__ void ApplyEdge(
    VertexId    s_id,
    VertexId    d_id,
    DataSlice   *d_data_slice,
    SizeT       edge_id,
    VertexId    input_item,
    LabelT      label,
    SizeT       input_pos,
    SizeT       &output_pos)
  {
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      d_data_slice->original_e[edge_id], d_data_slice->temp_index + s_id);
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   used for marking MST output array
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT = VertexId>
struct MarkFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Forward Advance Kernel condition function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   *
   * \return Whether to load the apply function for the edge and include
   * the destination node in the next frontier.
   */
  static __device__ __forceinline__ bool CondEdge(
        VertexId    s_id,
        VertexId    d_id,
        DataSlice   *d_data_slice,
        SizeT       edge_id,
        VertexId    input_item,
        LabelT      label,
        SizeT       input_pos,
        SizeT       &output_pos)
  {
    return true;
  }

  /**
   * @brief Forward Advance Kernel apply function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   */
  static __device__ __forceinline__ void ApplyEdge(
        VertexId    s_id,
        VertexId    d_id,
        DataSlice   *problem,
        SizeT       edge_id,
        VertexId    input_item,
        LabelT      label,
        SizeT       input_pos,
        SizeT       &output_pos)
  {
        // mark minimum spanning tree output edges
        util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
            (SizeT)1, problem->mst_output + problem->temp_index[s_id]);
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   used for removing cycles in successors
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT=VertexId>
struct CyRmFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Forward Advance Kernel condition function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   *
   * \return Whether to load the apply function for the edge and include
   * the destination node in the next frontier.
   */
  static __device__ __forceinline__ bool CondEdge(
        VertexId    s_id,
        VertexId    d_id,
        DataSlice   *problem,
        SizeT       edge_id,
        VertexId    input_item,
        LabelT      label,
        SizeT       input_pos,
        SizeT       &output_pos)
  {
    // cycle of length two
    return problem->successors[s_id] > s_id &&
      problem->successors[problem->successors[s_id]] == s_id;
  }

  /**
   * @brief Forward Advance Kernel apply function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   */
  static __device__ __forceinline__ void ApplyEdge(
        VertexId    s_id,
        VertexId    d_id,
        DataSlice   *problem,
        SizeT       edge_id,
        VertexId    input_item,
        LabelT      label,
        SizeT       input_pos,
        SizeT       &output_pos)
  {
    // remove cycles by assigning successor to its s_id
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      s_id, problem->successors + s_id);

    // remove some edges in the MST output result
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
        (SizeT)0, problem->mst_output + problem->temp_index[s_id]);
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions for pointer jumping operation.
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT=VertexId>
struct PJmpFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Filter Kernel condition function. The vertex id is always valid.
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v Vertex value
   * @param[in] nid Node ID
   *
   * \return Whether to load the apply function for the node and include
   * it in the outgoing vertex frontier.
   */
  static __device__ __forceinline__ bool CondFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *d_data_slice,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    return true;
  }

  /**
   * @brief Filter Kernel apply function. Point the current node to the
   * parent node of its parent node.
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v Vertex value
   * @param[in] nid Node ID
   */
  static __device__ __forceinline__ void ApplyFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    VertexId parent = problem->successors[node];
    VertexId grand_parent = problem->successors[parent];
    if (parent != grand_parent)
    {
        problem->done_flags[0] = 0;
        problem->successors[node] = grand_parent;
    }
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   used for remove redundant edges in one super-vertex
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT=VertexId>
struct EgRmFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Forward Advance Kernel condition function.
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   *
   * \return Whether to load the apply function for the edge and include
   * the destination node in the next frontier.
   */
  static __device__ __forceinline__ bool CondEdge(
        VertexId    s_id,
        VertexId    d_id,
        DataSlice   *problem,
        SizeT       edge_id,
        VertexId    input_item,
        LabelT      label,
        SizeT       input_pos,
        SizeT       &output_pos)
  {
    return problem->successors[s_id] == problem->successors[d_id];
  }

  /**
   * @brief Forward Advance Kernel apply function.
   * Each edge looks at the super-vertex id of both endpoints
   * and mark -1 (to be removed) if the id is the same
   *
   * @param[in] s_id Vertex Id of the edge source node
   * @param[in] d_id Vertex Id of the edge destination node
   * @param[in] problem Data slice object
   * @param[in] e_id Output edge index
   * @param[in] e_id_in Input edge index
   */
  static __device__ __forceinline__ void ApplyEdge(
        VertexId    s_id,
        VertexId    d_id,
        DataSlice   *problem,
        SizeT       edge_id,
        VertexId    input_item,
        LabelT      label,
        SizeT       input_pos,
        SizeT       &output_pos)
  {
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      (VertexId)-1, problem->keys_array + edge_id);
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      (VertexId)-1, problem->colindices + edge_id);
    //util::io::ModifiedStore<ProblemData::QUEUE_WRITE_MODIFIER>::St(
    //  (Value)-1, problem->edge_value + e_id);
    problem->edge_value[edge_id] = (Value) -1;
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      (VertexId)-1, problem->original_e + edge_id);
  }

  /**
   * @brief Filter Kernel condition function.
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v Vertex value
   * @param[in] nid Node ID
   *
   * \return Whether to load the apply function for the node and include
   * it in the outgoing vertex frontier.
   */
  static __device__ __forceinline__ bool CondFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *d_data_slice,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    return true;
  }

  /**
   * @brief Filter Kernel apply function.
   * removing edges belonging to the same super-vertex
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v Vertex value
   * @param[in] nid Node ID
   */
  static __device__ __forceinline__ void ApplyFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      problem->super_idxs[problem->keys_array[node]],
      problem->keys_array + node);
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      problem->super_idxs[problem->colindices[node]],
      problem->colindices + node);
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   used for calculating row_offsets array for next iteration
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 *
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT=VertexId>
struct RIdxFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Filter Kernel condition function.
   *   calculate new row_offsets
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v Vertex value
   * @param[in] nid Node ID
   *
   * \return Whether to load the apply function for the node and include
   * it in the outgoing vertex frontier.
   */
  static __device__ __forceinline__ bool CondFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    return problem->flag_array[node] == 1;
  }

  /**
   * @brief Filter Kernel apply function.
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v Vertex value
   * @param[in] nid Node ID
   *
   */
  static __device__ __forceinline__ void ApplyFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      node, problem->row_offset + problem->keys_array[node]);
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   used for generate edge flags
 *
 * @tparam VertexId    Type of signed integer use as vertex identifier
 * @tparam SizeT       Type of integer / unsigned integer for array indexing
 * @tparam Value       Type of integer / float / double to attributes
 * @tparam ProblemData Problem data type contains data slice for MST problem
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT=VertexId>
struct EIdxFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Filter Kernel condition function. Calculate new row_offsets
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v node value (if any)
   * @param[in] nid Node ID
   *
   * \return Whether to load the apply function for the node and include
   * it in the outgoing vertex frontier.
   */
  static __device__ __forceinline__ bool CondFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    return problem->edge_flags[node] == 1;
  }

  /**
   * @brief Filter Kernel apply function.
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v node value (if any)
   * @param[in] nid Node ID
   */
  static __device__ __forceinline__ void ApplyFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      node, problem->row_offset + problem->temp_index[node]);
  }
};

////////////////////////////////////////////////////////////////////////////////
/**
 * @brief Structure contains device functions in MST graph traverse.
 *   used for remove duplicated edges between super-vertices
 *
 * @tparam VertexId    Type of signed integer to use as vertex id
 * @tparam SizeT       Type of unsigned integer to use for array indexing
 * @tparam ProblemData Problem data type contains data slice for MST problem
 *
 */
template<
  typename VertexId,
  typename SizeT,
  typename Value,
  typename Problem,
  typename _LabelT=VertexId>
struct SuRmFunctor
{
  typedef typename Problem::DataSlice DataSlice;
  typedef _LabelT LabelT;

  /**
   * @brief Filter Kernel condition function.
   *   mark -1 for unselected edges / weights / keys / eId.
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v node value (if any)
   * @param[in] nid Node ID
   *
   * \return Whether to load the apply function for the node and include
   * it in the outgoing vertex frontier.
   */
  static __device__ __forceinline__ bool CondFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    return problem->edge_flags[node] == 0;
  }

  /**
   * @brief Filter Kernel apply function.
   *
   * @param[in] node Vertex Id
   * @param[in] problem Data slice object
   * @param[in] v node value (if any)
   * @param[in] nid Node ID
   */
  static __device__ __forceinline__ void ApplyFilter(
    VertexId    v,
    VertexId    node,
    DataSlice    *problem,
    SizeT       nid,
    LabelT      label,
    SizeT       input_pos,
    SizeT       output_pos)
  {
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      (VertexId)-1, problem->keys_array + node);
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      (VertexId)-1, problem->colindices + node);
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      (Value)   -1, problem->edge_value + node);
    util::io::ModifiedStore<Problem::QUEUE_WRITE_MODIFIER>::St(
      (VertexId)-1, problem->original_e + node);
  }
};

} // mst
} // app
} // gunrock

// Leave this at the end of the file
// Local Variables:
// mode:c++
// c-file-style: "NVIDIA"
// End:
