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
    #
    # jsonref is used to resolve $ref references
    # jsonref is not cyclic at this stage hence the need to make a
    # reasonable number of passes (2 below + 1 in the sf-schema directive)
    # to resolve cyclic references
    #
    MnoeMarketplace.findProduct(id: vm.subscription.product.id).then((response) ->
      vm.form = if response.asf_options then JSON.parse(response.asf_options) else ["*"]

      if response.custom_schema then JSON.parse(response.custom_schema) else {}
      ).then((schema) -> schemaForm.jsonref(schema))
      .then((schema) -> schemaForm.jsonref(schema))
      .then((schema) -> vm.schema = schema)

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
