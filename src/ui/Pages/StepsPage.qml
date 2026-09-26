import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Components 1.0

StackView {
    id: stepStack

    signal finished
    signal goTemplates

    readonly property var steps: [
        {
            title: "Hi! It`s Umbrage!",
            text: "Before we begin, would you like to use a user repository to retrieve the templates, or would you prefer to specify your own files?",
            image: "qrc:/assets/umbrage-icon2.svg",
            buttons: [
                {
                    text: "Use Templates",
                    outline: false,
                    onClicked: function () {
                        stepStack.goTemplates();
                    }
                },
                {
                    text: "Choose Manually",
                    outline: true,
                    onClicked: function (page) {
                        page.goNext();
                    }
                }
            ]
        },
        {
            title: "Download Agent",
            text: "Select the DA file to be used during interactions with the device.",
            image: "qrc:/assets/da_icon.svg",
            buttons: [
                {
                    text: "Choose file",
                    outline: false,
                    onClicked: function (page) {
                        page.chooseFile();
                    }
                }
            ]
        },
        {
            title: "Auth File",
            text: "Select the auth file if DAA is enabled in device.",
            image: "qrc:/assets/auth_icon.svg",
            buttons: [
                {
                    text: "Choose file",
                    outline: false,
                    onClicked: function (page) {
                        page.chooseFile();
                    }
                },
                {
                    text: "Skip",
                    outline: true,
                    onClicked: function (page) {
                        page.skip();
                    }
                }
            ]
        },
        {
            title: "Preloader File",
            text: "Do you have a preloader dump from your device?\nIt can be used for certain exploits.",
            image: "qrc:/assets/preloader_icon.svg",
            buttons: [
                {
                    text: "Choose file",
                    outline: false,
                    onClicked: function (page) {
                        page.chooseFile();
                    }
                },
                {
                    text: "Skip",
                    outline: true,
                    onClicked: function (page) {
                        page.skip();
                    }
                }
            ]
        },
    ]

    Component {
        id: stepComponent
        StepComponent {}
    }

    Component.onCompleted: pushStep(0)

    function pushStep(step) {
        var page = stepComponent.createObject(stepStack, {
            step: step,
            stepTitle: stepStack.steps[step].title,
            stepText: stepStack.steps[step].text,
            stepImage: stepStack.steps[step].image,
            isLastStep: step === stepStack.steps.length - 1
        });

        page.buttons = stepStack.steps[step].buttons;
        page.nextRequested.connect(function (nextStep) {
            stepStack.pushStep(nextStep);
        });
        page.backRequested.connect(stepStack.pop);
        page.finishedRequested.connect(function () {
            stepStack.finished();
        });

        push(page);
    }
}
