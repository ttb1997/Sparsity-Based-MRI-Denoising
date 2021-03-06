function [X Beta]=bmtl_DP_offgrid_2(A,B,Y,resolution,hyper)
%  Bayesian CSDP for off-grid wideband DOA
%  Implemented by Variational Bayes EM methods.
%
% Input:
%   A     - on grid Sensing Matrix, with size nd x N;
%   B       - derivation of A, with size nd x N;
%   Y       - Measurements data matrix, with size nd x M;
%
% Output:
%   X       - image data matirx, with size N x M;
%   hyper   - Some parameters possibily used in this programme.
% nd number of ULA; M measurements; N number of grids
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
if nargin < 4
    error('error!');
end

% Done, problem dimensions
[Mnd,N] = size(A); % Dimension of measurement matrix
[nd,M] = size(Y);   % Dimension of measurement signal

if nargin < 6
    hyper.truncateL = M;
    hyper.a = 1e-4;
    hyper.b = 1e-4;
%     hyper.c = ones(N,hyper.truncateL)*1e-6;
%     hyper.d = ones(N,hyper.truncateL)*1e-6;
    hyper.c = 1e-4;
    hyper.d = 1e-4;
    hyper.e = 1e-4;
    hyper.f = 1e-4;
    hyper.tao1 = ones(hyper.truncateL,1);
    hyper.tao2 = ones(hyper.truncateL,1);
    hyper.alpha0 = 1/(mean(var(Y))/N);% *1e3/ 1e-1;hyper.a / hyper.b 
%     [hyper.alpha,temp] = kmeans(hyper.alpha.',hyper.truncateL);
    hyper.z = zeros(hyper.truncateL,M);
    hyper.lambda = 1;
%     hyper.pi = zeros(hyper.truncateL,1);
    hyper.mu_x = zeros(N,M);%zeros(N,M);%A' * Y;
    hyper.mu_beta = zeros(N,hyper.truncateL);
    for ii = 1:M
        hyper.sigma_x(:,:,ii) = eye(N,N);
        hyper.alpha(:,ii) =  (1 ./ abs(A((ii-1)*nd+1:ii*nd,:)' * Y(:,ii)));%ones(N,1)*inf
        hyper.mu_x(:,ii)=A((ii-1)*nd+1:ii*nd,:)' * Y(:,ii);
    end
   
    hyper.kappa = abs(ones(hyper.truncateL,M));
    hyper.kappa = hyper.kappa ./ repmat(sum(hyper.kappa,1),hyper.truncateL,1);
%     hyper.kappa = zeros(hyper.truncateL,M);
%     hyper.kappa(1,:) = ones(1,M);
end

if nargin <6
    options.tol = 0.0001;% 0.005 may be suitable
    options.iter = 500;
end

%% Initialization
r = resolution*pi/180;
N_DOA = 2;
K = hyper.truncateL;
a = hyper.a; b = hyper.b;
c = hyper.c; d = hyper.d;
cnew = c * ones( N , K ); dnew = d * ones( N , K );
% cnew = ones(hyper.truncateL,1); dnew = ones(N,hyper.truncateL);
e = hyper.e; f = hyper.f;
z = hyper.z; 
% Pi = hyper.pi;
tao1_new = hyper.tao1; tao2_new =  hyper.tao2;
anew = a;
bnew = b;
lambda = hyper.lambda;
alpha0 = hyper.alpha0;
alpha = hyper.alpha;
mu_x = hyper.mu_x;
mu_beta=hyper.mu_beta;
Sigma_x = hyper.sigma_x;
kappa = hyper.kappa;
%% Main Iterations
for mmm=1:options.iter;
    mu_old=mu_x; 
   % fprintf(1,'This is the %dth iteration.\n',mmm);  % iteration number 
%% Update mu
for ii = 1 : M;
    temp_sigma_x = zeros(N,N);
    temp_mu_x = zeros(N,1);
    for jj= 1 : K
        Phi_k = A((ii-1)*nd+1:ii*nd,:)+B((ii-1)*nd+1:ii*nd,:)*diag(mu_beta(:,jj));
        PhikHPhik = Phi_k'*Phi_k;
        temp_sigma_x = temp_sigma_x + kappa(jj,ii)*(diag(alpha(:,jj))+alpha0*(PhikHPhik));
        temp_mu_x = temp_mu_x + kappa(jj,ii)* Phi_k'* Y( : , ii );
    end
    Sigma_x(:,:,ii) = inv(temp_sigma_x);
    mu_x(:,ii) = alpha0 * Sigma_x(:,:,ii) *  temp_mu_x;
end  

%% Update alpha
cnew = abs( repmat ( ( c + sum(kappa,2)).' , N , 1 ));
for jj = 1 : M
    temp(: , jj) = abs( mu_x(: , jj).^2) + real(diag(Sigma_x(: , : , jj)));
end
for jj = 1 : K
    dnew(: , jj) = sum(temp * diag(kappa( jj , : )) , 2);%+abs( mu_beta(: , jj).^2) + real(diag(Sigma_beta(: , : , jj)));
end
dnew = dnew + d;
alpha = abs(cnew ./ (dnew + eps));
p_alpha=abs(1 ./ alpha);
%% plot
% if mod(mmm,50)==0
%   figure; imagesc(abs(mu_x));
%   figure; imagesc(p_alpha);
% end
%% Update beta
kappa1=kappa;
[pos_k1 pos_k2]=find(kappa>0.00001);
kappa1(pos_k1,pos_k2)=1;
for jj = 1 : K;   
    % update beta
    [temp, idx] = sort(p_alpha(:,jj), 'descend');
    idx = sort(idx(1:N_DOA),'ascend');
    diff_idx = diff(idx);
    if any(diff_idx)==1
        pos_diff=find(diff_idx==1);
        for nnn=1:length(pos_diff)
        if p_alpha(idx(pos_diff(nnn)),jj)>=p_alpha(idx(pos_diff(nnn)+1),jj)
           idx(pos_diff(nnn)+1)= idx(pos_diff(nnn));
        else
           idx(pos_diff(nnn))= idx(pos_diff(nnn)+1);
        end
        end
    end
    idx = unique(idx);
    N_DOA_used=length(idx);
%     if N_DOA_used<KKK
%         N_DOA=KKK+1;
%     end
    temp = mu_beta(:,jj);
    mu_beta_jj = zeros(N,1);
    mu_beta_jj(idx) = temp(idx);
    temp_p_beta = zeros(N_DOA_used,N_DOA_used);
    temp_v_beta = zeros(N_DOA_used,1);
    for ii= 1 : M
        BHB=B((ii-1)*nd+1:ii*nd,idx)'*B((ii-1)*nd+1:ii*nd,idx);
        BHA=B((ii-1)*nd+1:ii*nd,idx)'*A((ii-1)*nd+1:ii*nd,:);
        temp_p_beta = temp_p_beta + kappa1(jj,ii)*(conj(BHB).*(mu_x(idx,ii)*mu_x(idx,ii)'+Sigma_x(idx,idx,ii)));
        temp_v_beta = temp_v_beta + kappa1(jj,ii)* (conj(mu_x(idx,ii)).*(B((ii-1)*nd+1:ii*nd,idx)'*(Y( : , ii )-A((ii-1)*nd+1:ii*nd,:)*mu_x(:,ii)))-diag(BHA*Sigma_x(:,idx,ii)));
    end
%  temp1 = real(temp_p_beta)\ real( temp_v_beta);

    if any(abs(diag(temp_p_beta)) <0.00000001)
            for n = 1:N_DOA_used               
                if abs (temp_p_beta(n,n)) < 0.00000001
                   mu_beta_jj(idx(n)) = 0;
                else
                temp_beta = mu_beta_jj(idx);
                temp_beta(n) = 0;
                mu_beta_jj(idx(n)) = (temp_v_beta(n) - temp_p_beta(n,:) * temp_beta) / temp_p_beta(n,n);
                end
            end
    else
        mu_beta_jj = zeros(N,1);
        mu_beta_jj(idx) = real(temp_p_beta)\ real( temp_v_beta);
    end
    for n=1:N_DOA_used
                if mu_beta_jj(idx(n)) > r/2
                    mu_beta_jj(idx(n)) = r/2;
                end
                if mu_beta_jj(idx(n)) < -r/2
                    mu_beta_jj(idx(n)) = -r/2;
                end
    end
    mu_beta(:,jj) = real(mu_beta_jj);
%     mu_beta(:,jj) = zeros(N,1);
    %clear idx mu_beta_jj;
end 

%% Update z
ita = zeros(K,M);
for ii = 1 : M;
%     AHA = A((ii-1)*nd+1:ii*nd,:)'*A((ii-1)*nd+1:ii*nd,:);
%     BHB = B((ii-1)*nd+1:ii*nd,:)'*B((ii-1)*nd+1:ii*nd,:);
%     AHB = A((ii-1)*nd+1:ii*nd,:)'*B((ii-1)*nd+1:ii*nd,:);
%     ita_1 = norm(Y( : , ii )-A((ii-1)*nd+1:ii*nd,:)*mu_x(:,ii),'fro')^2+trace(AHA*Sigma_x(:,:,ii));
%    ita_2 = Sigma_x(:,:,ii);%mu_x(:,ii)*mu_x(:,ii)'+
    for jj = 1 : K;
%         ita(jj,ii) = ita_1+trace((BHB.*(mu_beta(:,jj)*mu_beta(:,jj)'+Sigma_beta(:,:,jj)))*(ita_2))...
%             + 2*real(Y( : , ii )'*B((ii-1)*nd+1:ii*nd,:)*diag(mu_beta(:,jj))*mu_x(:,ii)-trace(AHB*diag(mu_beta(:,jj))*(ita_2)));
        ita(jj,ii) = norm(Y( : , ii )-(A((ii-1)*nd+1:ii*nd,:)+B((ii-1)*nd+1:ii*nd,:)*diag(mu_beta(:,jj)))*mu_x(:,ii),'fro')^2 ...
        + trace((A((ii-1)*nd+1:ii*nd,:)+B((ii-1)*nd+1:ii*nd,:)*diag(mu_beta(:,jj)))'*(A((ii-1)*nd+1:ii*nd,:)+B((ii-1)*nd+1:ii*nd,:)*diag(mu_beta(:,jj)))*Sigma_x(:,:,ii));
        if jj == 1;
        temp1(jj,ii) = 0;
        temp2(jj,ii) = psi(tao1_new(1) + eps) - psi(tao1_new(1) + tao2_new(1) + eps);
        elseif jj == K
        temp1(jj,ii) = sum ( psi( tao2_new(1 : jj-1) + eps ) - psi( tao1_new(1 : jj-1) + tao2_new(1 : jj-1) + eps) );
        temp2(jj,ii) = 0;
        else
        temp1(jj,ii) = sum ( psi( tao2_new(1 : jj-1) + eps ) - psi( tao1_new(1 : jj-1) + tao2_new(1 : jj-1) ) + eps );
        temp2(jj,ii) = psi(tao1_new(jj)+ eps ) - psi(tao1_new(jj) + tao2_new(jj) + eps );            
        end
        temp3(jj,ii) = real(nd*(log(anew)-log(bnew)))-alpha0*real(ita(jj,ii));
%         temp3(jj,ii) = 0;
        temp4(jj,ii) = real( sum( log((cnew(:,jj)+eps) ) - log((dnew(:,jj)) ) ))-real( trace( Sigma_x(:,:,ii) * diag( alpha(:,jj) ) ) + mu_x(:,ii)' * diag(alpha(:,jj)) * mu_x(:,ii) );
        temp5(jj,ii) = temp1(jj,ii) + temp2(jj,ii) + temp3(jj,ii) + temp4(jj,ii);
    end
end
%         psi((cnew) )
%         log((cnew) )
temp6 = exp( temp5 - repmat( max( temp5,[],1 ) , K , 1));
kappa = temp6 ./ (repmat( sum( temp6 , 1) , K , 1 ) );
% kappa
% figure; imagesc(abs(kappa))

%% Update tao
tao1 = 1;
tao2 = lambda;
for ii = 1 : K-1;
    tao1_new(ii) = sum(kappa(ii,:));
%     tao2_new(ii) = (K - ii) * sum(kappa(ii,:));
    tao2_new(ii) = sum(sum(kappa(ii+1:end,:)));
end
tao1_new = tao1_new + tao1;
tao2_new = tao2_new + tao2;
tao1_new(ii + 1) = 1;
tao2_new(ii + 1) = 1;

%% Update \lambda
enew = e + K - 1;
fnew = f - sum( psi(tao2_new(1:K-1) + eps) - psi(tao1_new(1:K-1) + tao2_new(1:K-1) + eps));
lambda = enew / (fnew + eps)*1.5;
anew = a + M * nd;
bnew = b +(sum(sum(kappa.*real(ita),1)));
alpha0 = abs(anew / bnew)/1.4;
%% stop criterion
if max(max(abs(mu_x-mu_old))) < options.tol
     for ii=1:M
    pos=find(1>alpha(:,ii) & alpha(:,ii)>0.0001);
    alpha(pos,ii)=1;
     end
    break;
end

end
 for ii=1:M
    pos=find(1>alpha(:,ii) & alpha(:,ii)>0.0001);
    alpha(pos,ii)=1;
 end
for ii = 1 : M;
    temp_sigma_x = zeros(N,N);
    temp_mu_x = zeros(N,1);
    for jj= 1 : K
        Phi_k = A((ii-1)*nd+1:ii*nd,:)+B((ii-1)*nd+1:ii*nd,:)*diag(mu_beta(:,jj));
        PhikHPhik = Phi_k'*Phi_k;
        temp_sigma_x = temp_sigma_x + kappa(jj,ii)*(diag(alpha(:,jj))+alpha0*(PhikHPhik));
        temp_mu_x = temp_mu_x + kappa(jj,ii)* Phi_k'* Y( : , ii );
    end
    Sigma_x(:,:,ii) = inv(temp_sigma_x);
    mu_x(:,ii) = alpha0 * Sigma_x(:,:,ii) *  temp_mu_x;
end
% cnew = abs( repmat ( ( c + sum(kappa,2)).' , N , 1 ));
% for jj = 1 : M
%     temp(: , jj) = abs( mu_x(: , jj).^2) + real(diag(Sigma_x(: , : , jj)));
% end
% for jj = 1 : K
%     dnew(: , jj) = sum(temp * diag(kappa( jj , : )) , 2);%+abs( mu_beta(: , jj).^2) + real(diag(Sigma_beta(: , : , jj)));
% end
% dnew = dnew + d;
% alpha = abs(cnew ./ (dnew + eps));
% p_alpha=abs(1 ./ alpha);
% N_DOA=2;
% [pos_k1 pos_k2]=find(kappa>0.001);
% kappa(pos_k1,pos_k2)=1;
% for jj = 1 : K;   
%     % update beta
%     [temp, idx] = sort(p_alpha(:,jj), 'descend');
%     idx = sort(idx(1:N_DOA),'ascend');
%     diff_idx = diff(idx);
%     if any(diff_idx)==1
%         pos_diff=find(diff_idx==1);
%         for nnn=1:length(pos_diff)
%          if p_alpha(idx(pos_diff(nnn)),jj)>=p_alpha(idx(pos_diff(nnn)+1),jj)
%            idx(pos_diff(nnn)+1)= idx(pos_diff(nnn));
%          else
%             idx(pos_diff(nnn))= idx(pos_diff(nnn)+1);
%          end
%         end
%     end
%     idx = unique(idx);
%     N_DOA_used=length(idx);
% %     if N_DOA_used<KKK
% %         N_DOA=KKK+1;
% %     end
%     temp = mu_beta(:,jj);
%     mu_beta_jj = zeros(N,1);
%     mu_beta_jj(idx) = temp(idx);
%     temp_p_beta = zeros(N_DOA_used,N_DOA_used);
%     temp_v_beta = zeros(N_DOA_used,1);
%     for ii= 1 : M
%         BHB=B((ii-1)*nd+1:ii*nd,idx)'*B((ii-1)*nd+1:ii*nd,idx);
%         BHA=B((ii-1)*nd+1:ii*nd,idx)'*A((ii-1)*nd+1:ii*nd,:);
%         temp_p_beta = temp_p_beta + kappa(jj,ii)*(conj(BHB).*(mu_x(idx,ii)*mu_x(idx,ii)'+Sigma_x(idx,idx,ii)));
%         temp_v_beta = temp_v_beta + kappa(jj,ii)* (conj(mu_x(idx,ii)).*(B((ii-1)*nd+1:ii*nd,idx)'*(Y( : , ii )-A((ii-1)*nd+1:ii*nd,:)*mu_x(:,ii)))-diag(BHA*Sigma_x(:,idx,ii)));
%     end
% %  temp1 = real(temp_p_beta)\ real( temp_v_beta);
% 
%     if any(abs(diag(temp_p_beta)) <0.00000001)
%             for n = 1:N_DOA_used               
%                 if abs (temp_p_beta(n,n)) < 0.00000001
%                    mu_beta_jj(idx(n)) = 0;
%                 else
%                 temp_beta = mu_beta_jj(idx);
%                 temp_beta(n) = 0;
%                 mu_beta_jj(idx(n)) = (temp_v_beta(n) - temp_p_beta(n,:) * temp_beta) / temp_p_beta(n,n);
%                 end
%             end
%     else
%         mu_beta_jj = zeros(N,1);
%         mu_beta_jj(idx) = real(temp_p_beta)\ real( temp_v_beta);
%     end
%     for n=1:N_DOA_used
%                 if mu_beta_jj(idx(n)) > r/2
%                     mu_beta_jj(idx(n)) = r/2;
%                 end
%                 if mu_beta_jj(idx(n)) < -r/2
%                     mu_beta_jj(idx(n)) = -r/2;
%                 end
%     end
%     mu_beta(:,jj) = real(mu_beta_jj);
% 
% end 
X = mu_x;
Beta = mu_beta*180/pi;
end
% function value = iszeros(theta,noise_level)
% theta = abs(theta);
% value = theta<=noise_level;
% end

