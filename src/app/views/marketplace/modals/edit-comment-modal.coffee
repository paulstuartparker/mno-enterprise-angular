angular.module 'mnoEnterpriseAngular'
.controller('EditCommentModalCtrl', ($log, $uibModalInstance, toastr, Utilities, MnoeMarketplace, object, app) ->
  vm = this

  vm.modal = {model: {}}
  vm.commentMaxLenght = 500

  vm.modal.model.description = object.description
  vm.modal.model.title = 'mno_enterprise.templates.dashboard.marketplace.show.edit_comment'
  vm.modal.model.placeholder = 'mno_enterprise.templates.dashboard.marketplace.show.comment_placeholder'

  vm.modal.cancel = ->
    $uibModalInstance.dismiss('cancel')

  vm.modal.proceed = () ->
    vm.modal.isLoading = true
    app_payload = {
      description: vm.modal.model.description
    }

    MnoeMarketplace.editComment(app.id, object.id, app_payload).then(
      (response) ->
        toastr.success('mno_enterprise.templates.dashboard.marketplace.show.success_toastr_2')
        $uibModalInstance.close(response)
      (errors) ->
        $log.error(errors)
        toastr.error('mno_enterprise.templates.dashboard.marketplace.show.error_toastr')
        Utilities.processRailsError(errors)
    ).finally(-> vm.modal.isLoading = false)

  return
)
