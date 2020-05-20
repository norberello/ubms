context("Stan input generation")

test_that("stan inputs are built correctly", {
  sc <- data.frame(x1=rnorm(5), group=factor(c("a","b","a","b","a")))
  state <- ubmsSubmodel("Occ", "state", sc, ~x1+(1|group), "plogis")
  det <- ubmsSubmodel("Det", "det", sc, ~x1, "plogis") 
  sl <- ubmsSubmodelList(state, det)
  y <- matrix(c(1,0,0,1,1,1,0,0,1), nrow=3, byrow=T)
  resp <- ubmsResponse(y, "binomial", "P")
  
  inp <- build_stan_inputs(resp, sl)
  expect_is(inp, "list")
  expect_equal(names(inp), c("stan_data", "pars"))
  
  gs1 <- get_stan_data(resp)
  gs2 <- get_stan_data(state)
  gs3 <- get_stan_data(det)
  gs_all <- c(gs1,gs2,gs3)
  expect_equal(inp$stan_data, gs_all)
})

test_that("parameter list for stan is generated correctly",{
  sc <- data.frame(x1=rnorm(5), group=factor(c("a","b","a","b","a")))
  state <- ubmsSubmodel("Occ", "state", sc, ~x1+(1|group), "plogis")
  det <- ubmsSubmodel("Det", "det", sc, ~x1, "plogis") 
  sl <- ubmsSubmodelList(state, det)
  sl <- unname(sl@submodels)
  pars <- get_pars(sl)
  expect_equal(pars, c("beta_state", "beta_det", "b_state", "sigma_state",
                       "log_lik"))
})

test_that("get_stan_data pulls necessary info from response object",{
  y <- matrix(c(1,0,0,1,1,1,0,0,1), nrow=3, byrow=T)
  resp <- ubmsResponse(y, "binomial", "P")
  dat <- get_stan_data(resp)
  expect_is(dat, "list")
  expect_equal(names(dat), c("y", "y_dist", "z_dist", "M", "T", "J",
                             "R", "K", "Kmin"))
  expect_equal(dat[[1]], as.vector(t(y)))
  expect_equal(dat[[2]], 0)
  expect_equal(dat[[3]], 1)
  expect_equal(dat[[4]], 3)
  expect_equal(dat[[5]], 1)
  expect_equal(dat[[6]], matrix(c(3,3,3), nrow=1))
  expect_equal(dat[[7]], 9)
  expect_equal(dat[[8]], max(y) + 20)
  expect_equal(dat[[9]], c(1,1,1))
})

test_that("dist_code returns integer code for distribution", {
  expect_equal(dist_code("binomial"), 0)
  expect_equal(dist_code("P"),1)
})

test_that("get_stan_data pulls necessary info from submodel",{
  sc <- data.frame(x1=rnorm(5))
  submod <- ubmsSubmodel("Occ", "state", sc, ~x1, "plogis") 
  dat <- get_stan_data(submod)
  expect_is(dat, "list")
  expect_equal(names(dat), 
               paste0(c("X","n_fixed","n_group_vars", "has_random",
                             "n_random", "Zdim", "Zw", "Zv", "Zu"),
                      "_", submod@type))
  expect_equivalent(dat[[1]], model.matrix(submod))
  expect_equal(dat[[2]], ncol(model.matrix(submod)))
  expect_equal(dat[[3]], get_group_vars(submod@formula))
  expect_equal(dat[[4]], has_random(submod))
  expect_equivalent(dat[6:9], get_sparse_Z(Z_matrix(submod)))
})

test_that("get_sparse_Z collapses Z into sparse parts",{

  Z1 <- matrix(0, nrow=0, ncol=0)
  Z2 <- matrix(c(1,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0), nrow=4)
  
  expect_equal(get_sparse_Z(Z1),
               list(Zdim=c(0,0,1,1,1), Zw=as.array(0),
                    Zv=as.array(0), Zu=as.array(0)))
  
  expect_equal(get_sparse_Z(Z2),
               list(Zdim=c(nrow(Z2), ncol(Z2), w=3, v=3, u=5),
                    Zw=c(1,1,1), Zv=c(1,2,4),
                    Zu=c(1,2,2,4,4)))
})

test_that("get_group_vars returns number of grouping variables",{
  expect_equal(get_group_vars(~x), 0) 
  expect_equal(get_group_vars(~(1|x)), 1)
  expect_equal(get_group_vars( ~(1|x) + (1|y)), 2)
})

test_that("get_nrandom returns number of levels of each grouping variable",{
  dat <- data.frame(x=factor(c("a","b","c")), y=factor("d","e"))
  expect_equal(get_nrandom(~x, dat), as.array(0))
  expect_equal(get_nrandom(~(1|x), dat), as.array(3))
  form <- ~(1|x) + (1|y)
  expect_equal(get_nrandom(form, dat), as.array(c(3,1)))
})

test_that("split_formula works",{
  inp <- ~1~1
  expect_equal(split_formula(inp), list(~1, ~1))
  inp <- ~x1~x2
  expect_equal(split_formula(inp), list(~x1, ~x2))
  inp <- ~x1+(1|x2)~x3
  expect_equal(split_formula(inp), list(~x1+(1|x2), ~x3))
  inp <- ~x1
  expect_error(split_formula(inp))
  inp <- y~x1
  expect_error(split_formula(inp))
})
