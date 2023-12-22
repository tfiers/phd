for i = 1:n-1           % forward Euler method
  v(i+1) = v(i)+tau*(k*(v(i)-vr)*(v(i)-vt)-u(i)+I(i))/C;
  u(i+1) = u(i)+tau*a*(b*(v(i)-vr)-u(i));
  if v(i+1) >= vpeak    % a spike is fired!
    v(i) = vpeak;       % padding the spike amplitude
    v(i+1) = c;         % membrane voltage reset
    u(i+1) = u(i+1)+d;  % recovery variable update
  end;
end;
