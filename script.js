console.log("VoxEarth Website Loaded");


const cards = document.querySelectorAll('.feature-card, .devlog-card');


window.addEventListener('scroll', () => {

    const triggerBottom = window.innerHeight * 0.85;

    cards.forEach(card => {

        const boxTop = card.getBoundingClientRect().top;

        if(boxTop < triggerBottom) {
            card.style.opacity = 1;
            card.style.transform = 'translateY(0px)';
        }

    });

});


cards.forEach(card => {

    card.style.opacity = 0;
    card.style.transform = 'translateY(50px)';
    card.style.transition = '0.6s';

});