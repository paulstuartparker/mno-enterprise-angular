angular.module 'mnoEnterpriseAngular'
  .controller('ProvisioningDetailsCtrl', ($scope, $q, $stateParams, $state, MnoeMarketplace, MnoeProvisioning, MnoeOrganizations, schemaForm) ->

    vm = this

    vm.subscription = MnoeProvisioning.getSubscription()

    # Happens when the user reload the browser during the provisioning
    if _.isEmpty(vm.subscription)
      # Redirect the user to the first provisioning screen
      $state.go('home.provisioning.order', {id: $stateParams.id, nid: $stateParams.nid}, {reload: true})

    vm.isEditMode = !_.isEmpty(vm.subscription.custom_data)

    # We must use model schemaForm's sf-model, as #json_schema_opts are namespaced under model
    vm.model = vm.subscription.custom_data || {}

    # Methods under the vm.model are used for calculated fields under #json_schema_opts.
    # Used to calculate the end date for forms with a contractEndDate.
    vm.model.calculateEndDate = (startDate, contractLength) ->
      return null unless startDate && contractLength
      moment(startDate)
      .add(contractLength.split('Months')[0], 'M')
      .format('YYYY-MM-DD')

    urlParams =
      orgId: $stateParams.orgId,
      id: $stateParams.id,
      nid: $stateParams.nid,
      editAction: $stateParams.editAction

    # The schema is contained in field vm.product.custom_schema
    # jsonref is used to resolve $ref references
    # jsonref is not cyclic at this stage hence the need to make a
    # reasonable number of passes (2 below + 1 in the sf-schema directive)
    # to resolve cyclic references
    setCustomSchema = (product) ->
      schemaForm.jsonref(JSON.parse(product.custom_schema))
        .then((schema) -> schemaForm.jsonref(schema))
        .then((schema) -> schemaForm.jsonref(schema))
        .then((schema) -> vm.schema = schema)

    orgPromise = MnoeOrganizations.get()
    prodsPromise = MnoeMarketplace.getProducts()
    initPromise = MnoeProvisioning.initSubscription({productNid: $stateParams.nid, subscriptionId: $stateParams.id})

    if _.isEmpty(vm.subscription)
      $q.all({organization: orgPromise, products: prodsPromise, subscription: initPromise}).then(
        (response) ->
          vm.orgCurrency = response.organization.organization?.billing_currency || MnoeConfig.marketplaceCurrency()
          vm.subscription = response.subscription
          vm.isEditMode = !_.isEmpty(vm.subscription.custom_data)
          # If the product id is available, get the product, otherwise find with the nid.
          productPromise = if vm.subscription.product?.id
            MnoeMarketplace.getProduct(vm.subscription.product.id, { editAction: $stateParams.editAction })
          else
            MnoeMarketplace.findProduct({nid: $stateParams.nid})

          productPromise.then(
            (response) ->
              vm.subscription.product = response
              # Filters the pricing plans not containing current currency
              vm.subscription.product.pricing_plans = _.filter(vm.subscription.product.pricing_plans,
                (pp) -> (pp.pricing_type in PRICING_TYPES['unpriced']) || _.some(pp.prices, (p) -> p.currency == vm.orgCurrency)
              )

              vm.select_plan = (pricingPlan)->
                vm.subscription.product_pricing = pricingPlan
                vm.subscription.max_licenses ||= 1 if vm.subscription.product_pricing.license_based

              MnoeProvisioning.setSubscription(vm.subscription)

              vm.subscription.product
          ).then((product) -> setCustomSchema(vm.subscription.product))
      ).finally(-> vm.isLoading = false)
    else if vm.subscription?.product?.custom_schema
      vm.isEditMode = !_.isEmpty(vm.subscription.custom_data)
      setCustomSchema(vm.subscription.product)
    else
      $state.go('home.provisioning.order', urlParams)

    vm.submit = (form) ->
      $scope.$broadcast('schemaFormValidate')
      return unless form.$valid
      vm.subscription.custom_data = vm.model
      MnoeProvisioning.setSubscription(vm.subscription)
      $state.go('home.provisioning.confirm', urlParams)

    # Delete the cached subscription when we are leaving the subscription workflow.
    $scope.$on('$stateChangeStart', (event, toState) ->
      switch toState.name
        when "home.provisioning.order", "home.provisioning.order_summary", "home.provisioning.confirm"
          null
        else
          MnoeProvisioning.setSubscription({})
    )

    return
  )
