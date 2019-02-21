
mutable struct MPS{T<:TensorStorage}
  N_::Int
  A_::Vector{ITensor{T}}
  llim_::Int
  rlim_::Int

  MPS() = new{Dense{Float64}}(0,Vector{ITensor{Dense{Float64}}}(),0,0)

  function MPS(N::Int, A::Vector{ITensor{T}}, llim::Int, rlim::Int) where {T<:TensorStorage}
    new{T}(N,A,llim,rlim)
  end

end

function MPS(sites::SiteSet)
  N = length(sites)
  MPS(N,fill(ITensor(Float64),N),0,N+1)
end

length(m::MPS) = m.N_
leftLim(m::MPS) = m.llim_
rightLim(m::MPS) = m.rlim_

getindex(m::MPS, n::Integer) = getindex(m.A_,n)
setindex!(m::MPS,T::ITensor,n::Integer) = setindex!(m.A_,T,n)

copy(m::MPS) = MPS(m.N_,copy(m.A_),m.llim_,m.rlim_)

function show(io::IO,
              psi::MPS)
  print(io,"MPS")
  (length(psi) > 0) && print(io,"\n")
  for i=1:length(psi)
    println(io,"$i  $(psi[i])")
  end
end

function linkind(psi::MPS,j::Integer) 
  li = commonindex(psi[j],psi[j+1])
  if isdefault(li)
    error("linkind: no MPS link index at link $j")
  end
  return li
end


function position!(psi::MPS,
                   j::Integer)
  N = length(psi)

  while leftLim(psi) < (j-1)
    ll = leftLim(psi)+1
    s = findtags(psi[ll],"Site")
    if ll == 1
      (Q,R) = qr(psi[ll],s)
    else
      li = linkind(psi,ll-1)
      (Q,R) = qr(psi[ll],s,li)
    end
    psi[ll] = Q
    psi[ll+1] *= R
    psi.llim_ += 1
  end

  while rightLim(psi) > (j+1)
    rl = rightLim(psi)-1
    s = findtags(psi[rl],"Site")
    if rl == N
      (Q,R) = qr(psi[rl],s)
    else
      ri = linkind(psi,rl)
      (Q,R) = qr(psi[rl],s,ri)
    end
    psi[rl] = Q
    psi[rl-1] *= R
    psi.rlim_ -= 1
  end
end

function overlap(psi1::MPS,
                 psi2::MPS)::Number64
  N = length(psi1)
  if length(psi2) != N
    error("overlap: mismatched lengths $N and $(length(psi2))")
  end

  s1 = findtags(psi2[1],"Site")
  O = psi1[1]*primeexcept(psi2[1],s1)
  for j=2:N
    sj = findtags(psi2[j],"Site")
    O *= psi1[j]
    O *= primeexcept(psi2[j],sj)
  end
  return O[]
end

function randomMPS(sites::SiteSet,
                   m::Int=1)
  psi = MPS(sites)
  for i=1:length(psi)
    psi[i] = randomITensor(sites[i])
    psi[i] /= norm(psi[i])
  end
  if m > 1
    error("randomMPS: currently only m==1 supported")
  end
  return psi
end
