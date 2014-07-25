% Genetic Algorithm Matlab/Octave Program
% For the Wind Park Layout Optimization Problem

function [bestSoln, bestCost]=gasimple(matrixSize, popsize, iterations, pc, pm, alpha, numOfTurbines)
    global pop popnew fitness fitold N size gridSize windVel rotorRadius crossoverAlpha;
      
    % Initializing the parameters]
    gridSize = 80;
    windVel=12;
    rotorRadius=20;
    crossoverAlpha=alpha;
    rand('state' ,0'); % Reset the random generator
    %popsize=20; % Population size
    MaxGen=iterations; % Max number of generations
    count=0;    % counter
    %pc=0.95;    % Crossover probability
    %pm=0.05;    % Mutation probability
    N = numOfTurbines;
    nsbit = 2*N;   % String length (bits)
    size = matrixSize;
    % Generating the initial population
    [popnew, fitness]=init_gen(popsize,nsbit);
    
    % Start the evolution loop
    for i=1:MaxGen,
        % Record as the history
        fitold=fitness; pop=popnew; 
        for j=1:popsize,
            % Crossover pair
            ii=floor(popsize*rand)+1; jj=floor(popsize*rand)+1;
            % Cross over
            if pc>rand,
                %TODO: check for duplicate locations?
                [popnew(ii,:),popnew(jj,:)]=crossover(pop(ii,:),pop(jj,:));
                % Evaluate the new pairs
                count=count+2;
                evolve(ii); 
                evolve(jj);
            end

            % Mutation at n sites
            if pm>rand,
                kk=floor(popsize*rand)+1; 
                count=count+1;
                popnew(kk,:)=mutate(pop(kk,:));
                evolve(kk);
            end
        end % end for j
        % Record the current best
        %bestfun(i)=max(fitness);
        %bestsol(i)=mean(sol(bestfun(i)==fitness));
    end
    
    [value,index] = max(fitness);
    bestSoln=chromesomeToMatrix(popnew(index,:));
    bestCost=value;
    
    % Display results
    %set(gcf,'color','w');
    %5subplot (2,1,1); plot(bestsol); title('Best estimates');
    %subplot(2,1,2); plot(bestfun); title('Fitness');
end

% All the sub functions
% generation of the initial population  
function [pop, fitness]=init_gen(np,nsbit)
    global N size
    
    fitness=zeros(1, np);
    pop=zeros(np, nsbit);
    for i = 1:np
        [pop(i, :),fitness(1,i)]=GenInitialSln(size, N);
    end
end

function [chromesome, result] = GenInitialSln(size, numTurbine)
    m=zeros(size,size);
    chromesome = zeros(1, numTurbine*2);
    count=0;
    while count<numTurbine
        i=ceil(rand()*size);
        j=ceil(rand()*size);
        if( m(i,j)==0 )
            m(i,j)=1;
            count=count+1;
            chromesome(1, count)=i;
            chromesome(1, count+numTurbine)=j;
        end
    end
    % cost of this individual
    % turn the cost function from a minimization to maximization
    result = calcFitness(m);
end

% Convert chromesome to wind park matrix
function matrix = chromesomeToMatrix(chromesome)
    global N size
    matrix = zeros(size, size);
    for i=1:N
       matrix(chromesome(i), chromesome(i+N))=1;
    end
end

% Calculate cost function for GA problem
function cost = calcFitness(m)
    f = CalculateCostFunc(m);
    cost = 1/(0.00001+f);
end

% Evolving the new generation
function evolve(j)
    global popnew fitness fitold pop;
    curSoln = chromesomeToMatrix(popnew(j,:));
    fitness(j)=calcFitness(curSoln);
    if fitness(j)>fitold(j),
        pop(j,:)=popnew(j,:);
    end
end

% Crossover operator
function [c,d]=crossover(a,b)
    global crossoverAlpha
    c = zeros(1, length(a));
    d = zeros(1, length(a));
    
    for i=1:length(a)
        c(i)=round(crossoverAlpha*a(i) + (1 - crossoverAlpha)*b(i));
        d(i)=round((1 - crossoverAlpha)*a(i) + crossoverAlpha*b(i));
    end
end

% Mutatation operator
function anew=mutate(a)
    global size N
    [anew, result] = GenInitialSln(size, N);
end

function result = CalculateCostFunc(m)
    N=sum(sum(m));
    cost = N*(2/3+1/3*exp(-0.00174*N^2));
    %cost
    result = cost / CalculateTotalPower(m);
end

function pwr = CalculateTotalPower(m)
    global size
    
    totalpower=0;
    for i = 1:size
        for j = 1:size
            if(m(i,j)==1)
                totalpower = totalpower+CalculateSingleTurbinePower(calculate_velocity(m,i,j));
            end
        end
    end
    pwr=totalpower;
end

function pwr = CalculateSingleTurbinePower(vel)
    global rotorRadius
    A = pi*rotorRadius^2;
    rho = 1.2;
    Cp = 0.35;
    Ng = 0.7;
    Nb = 0.95;
    
    pwr = 0.5 * rho * A * Cp * vel^3 * Ng * Nb;
end

function vel = calculate_velocity(matrix, x, y) 
    global gridSize size windVel

    %thrus coefficient of the turbine
    ct = 0.88;
    k = 2;
    R = 20;
    
    vel_def_total = 0;
    vel = windVel;
    
    for i = 1 : size
        for j = 1 : y-1
            if matrix(i,j)==1
                if check_wake(i*gridSize, j*gridSize, x*gridSize, y*gridSize)==1
                    vel_def_cur = (1-sqrt(1-ct))/(1+k*(y-j)*gridSize/R)^2;
                    vel_def_total = vel_def_total+vel_def_cur^2;
                end
            end
        end
    end
    vel_def = sqrt(vel_def_total);
    % do not update velocity if turbine is not affected by wake loss
    if (vel_def ~= 0)
        vel = windVel * (1-vel_def);
    end
end



%check if turbine i(x2,y2) is in wake of turbine j(x1,y1)
function check = check_wake(y1,x1,y2,x2)
    %wind direction is 0 degree
    theta =0;
    alpha = atan(2);
    R=20;
    k=2;
    
    numerator = (x2-x1)*cos(theta)+(y2-y1)*sin(theta)+R/k;
    denominator = sqrt( (x2-x1+R/k*cos(theta))^2 + (y2-y1+R/k*cos(theta))^2);
    beta = acos( numerator/denominator );

    if(beta<alpha)
        check=1;
    else
        check=0;
    end
end