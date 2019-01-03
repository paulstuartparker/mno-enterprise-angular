angular.module 'mnoEnterpriseAngular'
  .controller('ProvisioningSubscriptionsCtrl', ($q, $scope, $state, $stateParams, toastr, MnoeOrganizations, MnoeProvisioning, MnoeConfig, MnoConfirm, PRICING_TYPES, ProvisioningHelper) ->

    vm = this
    vm.isLoading = true
    vm.cartSubscriptions = $stateParams.subType == 'cart'
    vm.skipPriceSelection = ProvisioningHelper.skipPriceSelection

    vm.goToSubscription = (subscription) ->
      ProvisioningHelper.goToSubscription(subscription, vm.cartSubscriptions)

    vm.subscriptionsPromise = ->
      if vm.cartSubscriptions
        params = { where: {subscription_status_in: 'staged' } }
        MnoeProvisioning.getSubscriptions(params)
      else
        params = { where: {subscription_status_in: 'visible' } }
        MnoeProvisioning.getSubscriptions(params)

    vm.deleteCart = ->
      MnoeProvisioning.deleteCartSubscriptions().then(
        (response) ->
          MnoeProvisioning.emptyCartSubscriptions()
          toastr.info('mno_enterprise.templates.dashboard.provisioning.subscriptions.cart.delete_cart.toastr')
          $state.go("home.marketplace")
      )

    vm.submitCart = ->
      MnoeProvisioning.submitCartSubscriptions().then(
        (response) ->
          # Reload dock apps
          MnoeProvisioning.refreshCartSubscriptions()

          toastr.success('mno_enterprise.templates.dashboard.provisioning.subscriptions.cart.submit_cart.toastr')
          $state.go("home.subscriptions", {subType: 'active'})
      )

    vm.initialize = ->
      vm.isLoading = true
      orgPromise = MnoeOrganizations.get()
      subPromise = vm.subscriptionsPromise()

      $q.all({organization: orgPromise, subscriptions: subPromise}).then(
        (response) ->
          vm.subscriptions = response.subscriptions
          if vm.cartSubscriptions && vm.subscriptions.length < 1
            toastr.info('mno_enterprise.templates.dashboard.provisioning.subscriptions.cart.empty')
            $state.go('home.marketplace')
            return

          vm.orgCurrency = response.organization.organization?.billing_currency || MnoeConfig.marketplaceCurrency()

          # Is an up to date account required to allow app management and is the account past due?
          vm.paymentRequired = MnoeConfig.isCurrentAccountRequired() && response.organization.organization.in_arrears

          # If a subscription doesn't contains a pricing for the org currency, a warning message is displayed
          vm.displayCurrencyWarning = not _.every(response.subscriptions, (subscription) ->
            currencies = _.map(subscription?.product_pricing?.prices, 'currency')
            _.includes(currencies, vm.orgCurrency) || (subscription?.product_pricing?.pricing_type in PRICING_TYPES['unpriced'])
          )
      ).finally(-> vm.isLoading = false)

    #====================================
    # Post-Initialization
    #====================================
    $scope.$watch MnoeOrganizations.getSelectedId, (val) ->
      vm.initialize() if val?

    vm.displayInfoTooltip = (subscription) ->
      return subscription.status == 'aborted'

    vm.showEditAction = (subscription, editAction) ->
      return false if vm.paymentRequired
      ProvisioningHelper.showEditAction(subscription, editAction)

    vm.editSubscription = (subscription, editAction) ->
      ProvisioningHelper.editSubscription(subscription, editAction, vm.cartSubscriptions)

    vm.pendingSubscription = (subscription) ->
      subscription.status in ['pending', 'provisioning']

    vm.trimProductName = (name) ->
      return name.substring(0, 37)

    return
  )
