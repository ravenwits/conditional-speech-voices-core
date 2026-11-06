local A={values={1,2,3,4,5,6,7,8,9,10,15,20,30}}
function A.contains(n)return type(n)=="number" and n%1==0 and (n>=1 and n<=10 or n==15 or n==20 or n==30)end
return A
