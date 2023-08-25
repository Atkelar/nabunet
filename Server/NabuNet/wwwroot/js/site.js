// Please see documentation at https://docs.microsoft.com/aspnet/core/client-side/bundling-and-minification
// for details on configuring this project to bundle and minify static web assets.

document.addEventListener("DOMContentLoaded", () => {
    const loginDialog = document.getElementById('login-dialog');
    if (loginDialog) loginDialog.addEventListener('click', () => loginDialog.close());

    const loginDialogForm = document.getElementById('login-form');
    if (loginDialogForm) loginDialogForm.addEventListener('click', (event) => event.stopPropagation());
})