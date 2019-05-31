
mutable struct CProps
  ai::Vector{Int}
  bi::Vector{Int}
  ci::Vector{Int}
  nactiveA::Int 
  nactiveB::Int 
  nactiveC::Int
  AtoB::Vector{Int}
  AtoC::Vector{Int}
  BtoC::Vector{Int}
  permuteA::Bool
  permuteB::Bool
  permuteC::Bool
  dleft::Int 
  dmid::Int
  dright::Int
  ncont::Int
  Acstart::Int
  Bcstart::Int
  Austart::Int
  Bustart::Int
  PA::Vector{Int}
  PB::Vector{Int}
  PC::Vector{Int}
  ctrans::Bool
  newArange::Vector{Int}
  newBrange::Vector{Int}
  newCrange::Vector{Int}
  function CProps(ai::Vector{Int},
                  bi::Vector{Int},
                  ci::Vector{Int})
    new(ai,bi,ci,0,0,0,Vector{Int}(),Vector{Int}(),Vector{Int}(),false,false,false,1,1,1,0,
        length(ai),length(bi),length(ai),length(bi),Vector{Int}(),Vector{Int}(),Vector{Int}(),
        false,Vector{Int}(),Vector{Int}(),Vector{Int}())
  end
end

function compute_perms!(props::CProps)::Nothing
  #Use !AtoB.empty() as a check to see if we've already run this
  length(props.AtoB)!=0 && return

  na = length(props.ai)
  nb = length(props.bi)
  nc = length(props.ci)

  props.AtoB = fill(0,na)
  props.AtoC = fill(0,na)
  props.BtoC = fill(0,nb)
  for i = 1:na
    for j = 1:nb
      if props.ai[i]==props.bi[j]
        props.ncont += 1
        #TODO: check this if this should be i,j or i-1,j-1 (0-index or 1-index)
        i<=props.Acstart && (props.Acstart = i)
        j<=props.Bcstart && (props.Bcstart = j)
        props.AtoB[i] = j
        break
      end
    end
  end

  for i = 1:na
    for k = 1:nc
      if props.ai[i]==props.ci[k]
        #TODO: check this if this should be i,j or i-1,j-1 (0-index or 1-index)
        i<=props.Austart && (props.Austart = i)
        props.AtoC[i] = k
        break
      end
    end
  end

  for j = 1:nb
    for k = 1:nc
      if props.bi[j]==props.ci[k]
        #TODO: check this if this should be i,j or i-1,j-1 (0-index or 1-index)
        j<=props.Bustart && (props.Bustart = j)
        props.BtoC[j] = k
        break
      end
    end
  end

end

function is_trivial_permutation(P::Vector{Int})::Bool
  for n = 1:length(P)
    P[n]!=n && return false
  end
  return true
end

function checkACsameord(props::CProps)::Bool
  props.Austart>=length(props.ai) && return true
  aCind = props.AtoC[props.Austart]
  for i = 1:length(props.ai)
    if !contractedA(props,i)
      props.AtoC[i]!=aCind && return false
      aCind += 1
    end
  end
  return true
end

function checkBCsameord(props::CProps)::Bool
  props.Bustart>=length(props.bi) && return true
  bCind = props.BtoC[props.Bustart]
  for i = 1:length(props.bi)
    if !contractedB(props,i)
      props.BtoC[i]!=bCind && return false
      bCind += 1
    end
  end
  return true
end

contractedA(props::CProps,i::Int) = (props.AtoC[i]<1)
contractedB(props::CProps,i::Int) = (props.BtoC[i]<1)
Atrans(props::CProps) = contractedA(props,1)
Btrans(props::CProps) = !contractedB(props,1)
Ctrans(props::CProps) = props.ctrans

function find_index(v::Vector{Int},t)::Int
  for i = 1:length(v)
    v[i]==t && return i
  end
  return -1
end

function permute_extents(R,P)::Vector{Int}
  Rb = fill(0,length(R))
  n = 1
  for pn in P
    Rb[pn] = R[n]
    n += 1
  end
  return Rb
end

function compute!(props::CProps,
                  Adims::NTuple{NA,Int},
                  Bdims::NTuple{NB,Int}) where {NA,NB}
  compute_perms!(props)

  #Use props.PC.size() as a check to see if we've already run this
  length(props.PC)!=0 && return

  ra = length(props.ai)
  rb = length(props.bi)
  rc = length(props.ci)

  props.PC = fill(0,rc)

  props.dleft = 1
  props.dmid = 1
  props.dright = 1
  c = 1
  for i = 1:ra
    if !contractedA(props,i)
      props.dleft *= Adims[i]
      props.PC[c] = props.AtoC[i]
      c += 1
    else
      props.dmid *= Adims[i]
    end
  end
  for j = 1:rb
    if !contractedB(props,j)
      props.dright *= Bdims[j]
      props.PC[c] = props.BtoC[j]
      c += 1
    end
  end

  if !is_trivial_permutation(props.PC)
    props.permuteC = true
    if checkBCsameord(props) && checkACsameord(props)
      #Can avoid permuting C by 
      #computing Bt*At = Ct
      props.ctrans = true
      props.permuteC = false
    end
  end

  #Check if A can be treated as a matrix without permuting
  props.permuteA = false
  if !(contractedA(props,1) || contractedA(props,ra))
    #If contracted indices are not all at front or back, 
    #will have to permute A 
    props.permuteA = true
  else
    #Contracted ind start at front or back, check if contiguous
    #TODO: check that the limits are correct (1-indexed vs. 0-indexed)
    for i = 1:props.ncont
      if !contractedA(props,props.Acstart+i-1)
        #Contracted indices not contiguous, must permute
        props.permuteA = true
        break
      end
    end
  end

  #Check if B is matrix-like
  props.permuteB = false
  if !(contractedB(props,1) || contractedB(props,rb))
    #If contracted indices are not all at front or back, 
    #will have to permute B
    props.permuteB = true
  else
    #TODO: check that the limits are correct (1-indexed vs. 0-indexed)
    for i = 1:props.ncont
      if !contractedB(props,props.Bcstart+i-1)
        #Contracted inds not contiguous, permute
        props.permuteB = true
        break
      end
    end
  end

  if !props.permuteA && !props.permuteB
    #Check if contracted inds. in same order
    #TODO: check these limits are correct
    for i = 1:props.ncont
      if props.AtoB[props.Acstart+i-1]!=(props.Bcstart+i-1)
        #If not in same order, 
        #must permute one of A or B
        #so permute the smaller one
        props.dleft<props.dright ? (props.permuteA = true) : (props.permuteB = true)
        break
      end
    end
  end

  if props.permuteC && !(props.permuteA && props.permuteB)
    PCost(d::Real) = d*d
    #Could avoid permuting C if
    #permute both A and B, worth it?
    pCcost = PCost(props.dleft*props.dright)
    extra_pABcost = 0
    !props.permuteA && (extra_pABcost += PCost(props.dleft*props.dmid))
    !props.permuteB && (extra_pABcost += PCost(props.dmid*props.dright))
    if extra_pABcost<pCcost
      props.permuteA = true
      props.permuteB = true
      props.permuteC = false
    end
  end

  if props.permuteA
    props.PA = fill(0,ra)
    #Permute contracted indices to the front,
    #in the same order as on B
    newi = 0
    #TODO: check this is correct for 1-indexing
    bind = props.Bcstart
    for i = 1:props.ncont
      while !contractedB(props,bind) bind += 1 end
      j = find_index(props.ai,props.bi[bind])
      newi += 1
      props.PA[j] = newi #+1
      bind += 1
    end
    #Reset p.AtoC:
    fill!(props.AtoC,0)
    #Permute uncontracted indices to
    #appear in same order as on C
    #TODO: check this is correct for 1-indexing
    for k = 1:rc
      j = find_index(props.ai,props.ci[k])
      if j!=-1
        props.AtoC[newi] = k
        props.PA[j] = newi+1
        newi += 1
      end
      newi==ra && break
    end
  end

  ##Also update props.Austart,props.Acstart
  props.Acstart = ra+1
  props.Austart = ra+1
  #TODO: check this is correct for 1-indexing
  for i = 1:ra
    if contractedA(props,i)
      props.Acstart = min(i,props.Acstart)
    else
      props.Austart = min(i,props.Austart)
    end
    props.newArange = permute_extents(Adims,props.PA)
  end

  if(props.permuteB)
    props.PB = fill(0,rb)
    #TODO: check this is correct for 1-indexing
    newi = 0 #1
    if(props.permuteA)
      #A's contracted indices already set to
      #be in same order as B above, so just
      #permute contracted indices to the front
      #keeping relative order
      #TODO: how to translate this for loop?
      #for(int i = props.Bcstart; newi < props.ncont; ++newi)
      i = props.Bcstart
      #TODO: check this is correct for 1-indexing
      while newi < props.ncont
        while !contractedB(props,i) i += 1 end
        props.PB[i] = newi+1
        i += 1
        newi += 1
      end
    else
      #Permute contracted indices to the
      #front and in same order as on A
      aind = props.Acstart
      for i = 0:(props.ncont-1)
        while !contractedA(props,aind) aind += 1 end
        j = find_index(props.bi,props.ai[aind])
        newi += 1
        props.PB[j] = newi
        aind += 1
      end
    end
    #Reset p.BtoC:
    fill!(props.BtoC,0)
    #Permute uncontracted indices to
    #appear in same order as on C
    for k = 1:rc
      j = find_index(props.bi,props.ci[k])
      if j!=-1
        props.BtoC[newi] = k
        props.PB[j] = newi+1
        newi += 1
      end
      newi==rb && break
    end
    props.Bcstart = rb
    props.Bustart = rb
    for i = 1:rb
      if(contractedB(props,i))
          props.Bcstart = min(i,props.Bcstart)
      else
          props.Bustart = min(i,props.Bustart)
      end
    end
    props.newBrange = permute_extents(Bdims,props.PB)
  end

  if props.permuteA || props.permuteB
    #Recompute props.PC
    c = 1
    #TODO: check this is correct for 1-indexing
    for i = 1:ra
      if !contractedA(props,i)
        props.PC[c] = props.AtoC[i]
        c += 1
      end
    end
    #TODO: check this is correct for 1-indexing
    for j = 1:rb
      if !contractedB(props,j)
        props.PC[c] = props.BtoC[j]
        c += 1
      end
    end
    props.ctrans = false
    if(is_trivial_permutation(props.PC))
      props.permuteC = false
    else
      props.permuteC = true
      #Here we already know since pc_triv = false that
      #at best indices from B precede those from A (on result C)
      #so if both sets remain in same order on C 
      #just need to transpose C, not permute it
      if  checkBCsameord(props) && checkACsameord(props)
        props.ctrans = true
        props.permuteC = false
      end
    end
  end

  if props.permuteC
    Rb = Int[]
    if !props.permuteA
      #TODO: check this is correct for 1-indexing
      for i = 1:ra
        if !contractedA(props,i)
          push!(Rb,size(A,i))
        end
      end
    else
      #TODO: check this is correct for 1-indexing
      for i = 1:ra
        if !contractedA(props,i)
          push!(Rb,size(props.newArange,i))
        end
      end
    end
    if !props.permuteB
      #TODO: check this is correct for 1-indexing
      for j = 1:rb
        if !contractedB(props,j)
          push!(Rb,size(B,j))
        end
      end
    else
      #TODO: check this is correct for 1-indexing
      for j = 1:rb
        if !contractedB(props,j)
          push!(Rb,size(props.newBrange,j))
        end
      end
    end
    props.newCrange = Rb
  end

end

function contract!(Cstore::Dense{Float64},
                   Cdims::NTuple{NC,Int},
                   p::CProps,
                   Astore::Dense{Float64},
                   Adims::NTuple{NA,Int},
                   Bstore::Dense{Float64},
                   Bdims::NTuple{NB,Int}) where {NA,NB,NC}
  # TODO: This is because the permutation convention in C++ ITensor and
  # permutedims in Julia is different
  p.PA = inv(Permutation(p.PA)).data
  p.PB = inv(Permutation(p.PB)).data
  p.PC = inv(Permutation(p.PC)).data

  A = reshape(data(Astore),Adims)
  B = reshape(data(Bstore),Bdims)
  C = reshape(data(Cstore),Cdims)

  tA = 'N'
  if p.permuteA
    aref::Matrix{Float64} = reshape(permutedims(A,p.PA),p.dmid,p.dleft)
    tA = 'T'
  else
    #A doesn't have to be permuted
    if Atrans(p)
      aref = reshape(A,p.dmid,p.dleft)
      tA = 'T'
    else
      aref = reshape(A,p.dleft,p.dmid)
    end
  end

  tB = 'N'
  if p.permuteB
    bref::Matrix{Float64} = reshape(permutedims(B,p.PB),p.dmid,p.dright)
  else
    if Btrans(p)
      bref = reshape(B,p.dright,p.dmid)
      tB = 'T'
    else
      bref = reshape(B,p.dmid,p.dright)
    end
  end

  if p.permuteC
    cref::Matrix{Float64} = reshape(copy(C),p.dleft,p.dright)
  else
    if Ctrans(p)
      cref = reshape(C,p.dleft,p.dright)
      if tA=='N' && tB=='N'
        (aref,bref) = (bref,aref)
        tA = tB = 'T'
      elseif tA=='T' && tB=='T'
        (aref,bref) = (bref,aref)
        tA = tB = 'N'
      end
    else
      cref = reshape(C,p.dleft,p.dright)
    end
  end

  BLAS.gemm!(tA,tB,1.0,aref,bref,0.0,cref)
 
  if p.permuteC
    permutedims!(C,reshape(cref,p.newCrange...),p.PC)
  end
  return
end

function contract_scalar!(Cstore::Dense{Float64},Clabels::Vector{Int},
                          Bstore::Dense{Float64},Blabels::Vector{Int},α::Float64)
  p = calculate_permutation(Blabels,Clabels)
  Bdata = data(Bstore)
  Cdata = data(Cstore)
  if is_trivial_permutation(p)
    Cdata .= α.*Bdata
  else
    #TODO: make an optimized permutedims!() that also scales the data
    permutedims!(Cdata,α*Bdata)
  end
  return
end

function contract!(Cstore::Dense{Float64},
                   Cdims::NTuple{NC,Int},
                   Clabels::Vector{Int},
                   Astore::Dense{Float64},
                   Adims::NTuple{NA,Int},
                   Alabels::Vector{Int},
                   Bstore::Dense{Float64},
                   Bdims::NTuple{NB,Int},
                   Blabels::Vector{Int}) where {NA,NB,NC}
  if(length(Alabels)==0)
    contract_scalar!(Cstore,Clabels,Bstore,Blabels,Adata[1])
  elseif(length(Blabels)==0)
    contract_scalar!(Cstore,Clabels,Astore,Alabels,Bdata[1])
  else
    props = CProps(Alabels,Blabels,Clabels)
    compute!(props,Adims,Bdims)
    contract!(Cstore,Cdims,props,Astore,Adims,Bstore,Bdims)
  end
  return
end

