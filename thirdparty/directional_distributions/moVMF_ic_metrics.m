function [ aic, bic ] = moVMF_ic_metrics(Data,Priors,LogLik)
%moVMF_BIC Information criterion Metrics
%
%  input ------------------------------------------------------------------
%
%   o Data:     D x N array representing N datapoints of D dimensions.
%
%   o Priors:   1 x K array representing the prior probabilities of the
%               K VMF components.

%  output -----------------------------------------------------------------
%
%   o bic   : (1 x 1)
%
%   o aic   : (1 x 1)




[D,N]       = size(Data);
K           = length(Priors);
num_param   = K-1 + K * D + K;

aic    = - 2 * LogLik + 2 * num_param;
bic    = - 2 * LogLik + num_param * log(N);

end

