export hasindex,
       hasinds,
       hassameinds,
       findindex,
       findinds,
       swaptags,
       swapprime,
       mapprime,
       commoninds,
       commonindex,
       uniqueinds,
       uniqueindex

struct IndexSet
    len::Int
    inds::NTuple{6,Index}

    IndexSet() = new(0,(Index(),Index(),Index(),Index(),Index(),Index()))
    IndexSet(i1::Index) = new(1,(i1,Index(),Index(),Index(),Index(),Index()))
    IndexSet(i1::Index,i2::Index) = new(2,(i1,i2,Index(),Index(),Index(),Index()))
    IndexSet(i1::Index,i2::Index,i3::Index) = new(3,(i1,i2,i3,Index(),Index(),Index()))
    IndexSet(i1::Index,i2::Index,i3::Index,i4::Index) = new(4,(i1,i2,i3,i4,Index(),Index()))
    IndexSet(i1::Index,i2::Index,i3::Index,i4::Index,i5::Index) = new(5,(i1,i2,i3,i4,i5,Index()))
    IndexSet(i1::Index,i2::Index,i3::Index,i4::Index,i5::Index,i6::Index) = new(6,(i1,i2,i3,i4,i5,i6))

    function IndexSet(vi::Vector{Index})
      li = length(vi)
      n = 1
      is = ntuple(x->Index(),6)
      while (n <= li) && !isdefault(vi[n])
        is = setindex(is,vi[n],n)
        n += 1
      end
      return new(n-1,is)
      #li = length(i)
      #if li >= 6
      #  return new(6,(i[1],i[2],i[3],i[4],i[5],i[6]))
      #end
      #return new(li,tuple(i...,ntuple(x->Index(),6-li)...))
    end
end


# Construct of some size
#IndexSet(N::Integer) = IndexSet(Vector{Index}(undef,N))

# Construct from various sets of indices
IndexSet(inds::Index...) = IndexSet(Index[inds...])
IndexSet(inds::NTuple{N,Index}) where {N} = IndexSet(inds...)

# Construct from various sets of IndexSets
IndexSet(inds::IndexSet) = inds
#IndexSet(inds::IndexSet,i::Index) = IndexSet(inds...,i)
#IndexSet(i::Index,inds::IndexSet) = IndexSet(i,inds...)
#IndexSet(is1::IndexSet,is2::IndexSet) = IndexSet(is1...,is2...)
#IndexSet(inds::NTuple{2,IndexSet}) = IndexSet(inds...)

length(is::IndexSet) = is.len

# Convert to an Index if there is only one
Index(is::IndexSet) = length(is)==1 ? is[1] : error("Number of Index in IndexSet ≠ 1")

getindex(is::IndexSet,n::Integer) = getindex(is.inds,n)
#setindex!(is::IndexSet,i::Index,n::Integer) = setindex!(is.inds,i,n)
order(is::IndexSet) = length(is)
copy(is::IndexSet) = IndexSet(copy(is.inds))
dims(is::IndexSet) = Tuple(dim(i) for i ∈ is)
function dim(is::IndexSet)::Int
  d = 1
  for n=1:6
    isdefault(is[n]) && break
    d *= dim(is[n])
  end
  return d
end
dim(is::IndexSet,pos::Integer) = dim(is[pos])

dag(is::IndexSet) = IndexSet(dag.(is.inds))

# Allow iteration
size(is::IndexSet) = size(is.inds)
iterate(is::IndexSet,state::Int=1) = iterate(is.inds,state)

#push!(is::IndexSet,i::Index) = push!(is.inds,i)

function push!(is::IndexSet,i::Index) 
  is = IndexSet(tuple(is.inds...,i))
end

# 
# Set operations
#

# inds has the index i
function hasindex(inds,i::Index)
  is = IndexSet(inds)
  for j ∈ is
    i==j && return true
  end
  return false
end

# Binds is subset of Ainds
function hasinds(Binds,Ainds)
  Ais = IndexSet(Ainds)
  for i ∈ Ais
    !hasindex(Binds,i) && return false
  end
  return true
end
hasinds(Binds,Ainds::Index...) = hasinds(Binds,IndexSet(Ainds...))

# Set equality (order independent)
function hassameinds(Ainds,Binds)
  Ais = IndexSet(Ainds)
  Bis = IndexSet(Binds)
  return hasinds(Ais,Bis) && length(Ais) == length(Bis)
end

"""
==(is1::IndexSet, is2::IndexSet)

IndexSet quality (order dependent)
"""
function ==(Ais::IndexSet,Bis::IndexSet)
  length(Ais) ≠ length(Bis) && return false
  for i ∈ 1:length(Ais)
    Ais[i] ≠ Bis[i] && return false
  end
  return true
end

# Helper function for uniqueinds
# Return true if the Index is not in any
# of the input sets of indices
function _is_unique_index(j::Index,inds...)
  for I ∈ inds
    hasindex(I,j) && return false
  end
  return true
end

"""
uniqueinds(Ais,Bis...)

Output the IndexSet with Indices in Ais but not in
the IndexSets Bis.
"""
function uniqueinds(Ainds,Binds...)
  Ais = IndexSet(Ainds)
  Cis = IndexSet()
  for j ∈ Ais
    _is_unique_index(j,Binds...) && push!(Cis,j)
  end
  return Cis
end

"""
uniqueindex(Ais,Bis...)

Output the Index in Ais but not in the IndexSets Bis.
If more than one Index is found, throw an error.
Otherwise, return a default constructed Index.
"""
uniqueindex(Ais,Bis...) = Index(uniqueinds(Ais,Bis...))

setdiff(Ais::IndexSet, Bis::IndexSet...) = uniqueinds(Ais,Bis...)

"""
commoninds(Ais,Bis)

Output the IndexSet in the intersection of Ais and Bis
"""
function commoninds(Ainds,Binds)
  Ais = IndexSet(Ainds)
  Cis = IndexSet()
  for i ∈ Ais
    hasindex(Binds,i) && push!(Cis,i)
  end
  return Cis
end

"""
commonindex(Ais,Bis)

Output the Index common to Ais and Bis.
If more than one Index is found, throw an error.
Otherwise, return a default constructed Index.
"""
commonindex(Ais,Bis) = Index(commoninds(Ais,Bis))

"""
findinds(inds,tags)

Output the IndexSet containing the subset of indices
of inds containing the tags in the input tagset.
"""
function findinds(inds,tags)
  is = IndexSet(inds)
  ts = TagSet(tags)
  found_inds = IndexSet()
  for i ∈ is
    if hastags(i,ts)
      push!(found_inds,i)
    end
  end
  return found_inds
end
"""
findinds(inds,tags)

Output the Index containing the tags in the input tagset.
If more than one Index is found, throw an error.
Otherwise, return a default constructed Index.
"""
findindex(inds, tags) = Index(findinds(inds,tags))

# From a tag set or index set, find the positions
# of the matching indices as a vector of integers
indexpositions(inds, match::Nothing) = collect(1:length(inds))
# Version for matching a tag set
function indexpositions(inds, match::T) where {T<:Union{AbstractString,TagSet}}
  is = IndexSet(inds)
  tsmatch = TagSet(match)
  pos = Int[]
  for (j,I) ∈ enumerate(is)
    hastags(I,tsmatch) && push!(pos,j)
  end
  return pos
end
# Version for matching a collection of indices
function indexpositions(inds, match)
  is = IndexSet(inds)
  ismatch = IndexSet(match)
  pos = Int[]
  for (j,I) ∈ enumerate(is)
    hasindex(ismatch,I) && push!(pos,j)
  end
  return pos
end
# Version for matching a list of indices
indexpositions(inds, match_inds::Index...) = indexpositions(inds, IndexSet(match_inds...))

#
# Tagging functions
#

function prime!(is::IndexSet, plinc::Integer, match = nothing)
  pos = indexpositions(is, match)
  for jj ∈ pos
    is[jj] = prime(is[jj],plinc)
  end
  return is
end
prime!(is::IndexSet,match=nothing) = prime!(is,1,match)
prime(is::IndexSet, vargs...) = prime!(copy(is), vargs...)
# For is' notation
adjoint(is::IndexSet) = prime(is)

function setprime!(is::IndexSet, plev::Integer, match = nothing)
  pos = indexpositions(is, match)
  for jj ∈ pos
    is[jj] = setprime(is[jj],plev)
  end
  return is
end
setprime(is::IndexSet, vargs...) = setprime!(copy(is), vargs...)

noprime!(is::IndexSet, match = nothing) = setprime!(is, 0, match)
noprime(is::IndexSet, vargs...) = noprime!(copy(is), vargs...)

function addtags!(is::IndexSet,
                  tags,
                  match = nothing)
  pos = indexpositions(is, match)
  for jj ∈ pos
    is[jj] = addtags(is[jj],tags)
  end
  return is
end
addtags(is, vargs...) = addtags!(copy(is), vargs...)

function settags!(is::IndexSet,
                  ts,
                  match = nothing)
  pos = indexpositions(is, match)
  for jj ∈ pos
    is[jj] = settags(is[jj],ts)
  end
  return is
end
settags(is, vargs...) = settags!(copy(is), vargs...)

function removetags!(is::IndexSet,
                     tags,
                     match = nothing)
  pos = indexpositions(is, match)
  for jj ∈ pos
    is[jj] = removetags(is[jj],tags)
  end
  return is
end
removetags(is, vargs...) = removetags!(copy(is), vargs...)

function replacetags!(is::IndexSet,
                      tags_old, tags_new,
                      match = nothing)
  pos = indexpositions(is, match)
  for jj ∈ pos
    is[jj] = replacetags(is[jj],tags_old,tags_new)
  end
  return is
end
replacetags(is, vargs...) = replacetags!(copy(is), vargs...)

function swaptags!(is::IndexSet,
                   tags1, tags2,
                   match = nothing)
  ts1 = TagSet(tags1)
  ts2 = TagSet(tags2)
  tstemp = TagSet("e43efds")
  plev(ts1) ≥ 0 && (tstemp = setprime(tstemp,431534))
  replacetags!(is, ts1, tstemp, match)
  replacetags!(is, ts2, ts1, match)
  replacetags!(is, tstemp, ts2, match)
  return is
end
swaptags(is, vargs...) = swaptags!(copy(is), vargs...)

function calculate_permutation(set1, set2)
  l1 = length(set1)
  l2 = length(set2)
  #l1==l2 || throw(DimensionMismatch("Mismatched input sizes in calcPerm: l1=$l1, l2=$l2"))
  if l1!=l2 
    @show set1
    @show set2
    throw(DimensionMismatch("Mismatched input sizes in calcPerm: l1=$l1, l2=$l2"))
  end
  p = zeros(Int,l1)
  for i1 = 1:l1
    for i2 = 1:l2
      if set1[i1]==set2[i2]
        p[i1] = i2
        break
      end
    end #i2
    p[i1]!=0 || error("Sets aren't permutations of each other")
  end #i1
  return p
end

function compute_contraction_labels(Ai::IndexSet,Bi::IndexSet)
  rA = order(Ai)
  rB = order(Bi)
  Aind = zeros(Int,rA)
  Bind = zeros(Int,rB)

  ncont = 0
  for i = 1:rA, j = 1:rB
    if Ai[i]==Bi[j]
      Aind[i] = Bind[j] = -(1+ncont)
      ncont += 1
    end
  end

  u = ncont
  for i = 1:rA
    if(Aind[i]==0) Aind[i] = (u+=1) end
  end
  for j = 1:rB
    if(Bind[j]==0) Bind[j] = (u+=1) end
  end

  return (Aind,Bind)
end

function contract_inds(Ais::IndexSet,
                       Aind,
                       Bis::IndexSet,
                       Bind)
  ncont = 0
  for i in Aind
    if(i < 0) ncont += 1 end 
  end
  nuniq = length(Ais)+length(Bis)-2*ncont
  Cind = zeros(Int,nuniq)
  Cis = fill(Index(),nuniq)
  u = 1
  for i ∈ 1:length(Ais)
    if(Aind[i] > 0) 
      Cind[u] = Aind[i]; 
      Cis[u] = Ais[i]; 
      u += 1 
    end
  end
  for i ∈ 1:length(Bis)
    if(Bind[i] > 0) 
      Cind[u] = Bind[i]; 
      Cis[u] = Bis[i]; 
      u += 1 
    end
  end
  return (IndexSet(Cis...),Cind)
end

function compute_strides(inds::IndexSet)
  r = order(inds)
  stride = zeros(Int, r)
  s = 1
  for i = 1:r
    stride[i] = s
    s *= dim(inds[i])
  end
  return stride
end

