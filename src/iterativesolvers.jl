
function davidson(A,
                  phi0::ITensor{Dense{Float64}};
                  kwargs...)
  phi = copy(phi0)

  maxiter = get(kwargs,:maxiter,3)
  miniter = get(kwargs,:miniter,1)
  errgoal = get(kwargs,:errgoal,1E-14)
  Northo_pass = get(kwargs,:Northo_pass,2)

  approx0 = 1E-12

  nrm = norm(phi)
  if nrm < 1E-18 
    randn!(phi)
    nrm = norm(phi)
  end
  phi /= nrm

  maxsize = size(A)[1]
  actual_maxiter = min(maxiter,maxsize-1)

  if dim(inds(phi)) != maxsize
    error("linear size of A and dimension of phi should match in davidson")
  end

  V = ITensor{Dense{Float64}}[phi]
  AV = ITensor{Dense{Float64}}[A(phi)]

  #@show V
  #@show AV

  #@show inds(V[1])
  #@show inds(AV[1])

  last_lambda = NaN
  lambda = dot(V[1],AV[1])
  q = AV[1] - lambda*V[1];

  M = fill(lambda,(1,1))

  for ni=1:actual_maxiter+1

    if ni > 1
      #@show M
      F = eigen(Hermitian(M))
      lambda = F.values[1]
      u = F.vectors[:,1]
      phi = u[1]*V[1]
      q = u[1]*AV[1]
      for n=2:ni
        phi += u[n]*V[n]
        q   += u[n]*AV[n]
      end
      #phinrm = norm(phi)
      #phi /= phinrm
      #q /= phinrm
      q -= lambda*phi
      #Fix sign
      if real(u[1]) < 0
        phi *= -1.0
        q *= -1.0
      end
    end

    qnorm = norm(q)

    errgoal_reached = (qnorm < errgoal && abs(lambda-last_lambda) < errgoal)
    small_qnorm = (qnorm < max(approx0,errgoal*1E-3))
    converged = errgoal_reached || small_qnorm

    if (qnorm < 1E-20) || (converged && ni > miniter_) || (ni >= actual_maxiter)
      #@printf "  done with davidson, ni=%d, qnorm=%.3E\n" ni qnorm
      break
    end

    last_lambda = lambda

    pass = 1
    while pass <= Northo_pass
      for k=1:ni
        q += -dot(V[k],q)*V[k]
      end
      qnrm = norm(q)
      if qnrm < 1E-10 #orthog failure, try randomizing
        # TODO: put random recovery code here
        error("orthog failure")
      end
      q /= qnrm
      pass += 1
    end

    push!(V,q)
    push!(AV,A(q))

    newM = fill(0.0,(ni+1,ni+1))
    newM[1:ni,1:ni] = M
    for k=1:ni+1
      newM[k,ni+1] = dot(V[k],AV[ni+1])
      newM[ni+1,k] = conj(newM[k,ni+1])
    end
    M = newM
  end #for ni=1:actual_maxiter+1

  #phi /= norm(phi)

  return lambda,phi

end

