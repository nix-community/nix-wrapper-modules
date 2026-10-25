(function () {
  window.addEventListener("load", function () {
    // Add dropdown arrows to the sidebar, using the existing functionality from mdbook's toc.js
    const foldable_sidebar = document.querySelectorAll(".sidebar-scrollbox span:has(+ ol)");
    foldable_sidebar.forEach(header => {
      header.insertAdjacentHTML('beforeend', '<a class="chapter-fold-toggle header-toggle"><div>❱</div></a>');
      header.querySelector("a.header-toggle").addEventListener("click", () => {
        header.closest("li").classList.toggle("expanded");
      });
    });
  });
})();
(function () {
  const marker = document.querySelector("#mdbook-content div[nix-wrapper-module-documentation-style-tag][hidden]");
  if (!marker) return;

  const customCSS = document.createElement("style");
  customCSS.textContent = `
    /* Set headings to display next to the details element dropdown */
    details > summary > h1, details > summary > h2, details > summary > h3 {
      display: inline;
    }
    /* Indent module subsections (they are details elements in the module's details element) */
    details > details{
      padding-left: 20px;
    }
  `;
  document.head.appendChild(customCSS);

  // Sets the sidebar sections open/closed status to match the open/closed state of the relevant details element
  // Relies on the fact that module headings are the only level 2 headings inside the summary of a details element
  function updateSidebarFromDetailsElement(details) {
    const module_heading = details.querySelector("summary h2");
    if (!module_heading) return;

    const module_sidebar = document.querySelector(`.sidebar-scrollbox a[href="#${module_heading.id}"]`);
    if (!module_sidebar) return;

    const sidebar_li = module_sidebar.closest("li");
    if (!sidebar_li) return;

    if (details.open) {
      sidebar_li.classList.add("expanded");
    } else {
      sidebar_li.classList.remove("expanded");
    }
  }

  // Set up listeners immediately
  const foldable_details = document.querySelectorAll("#mdbook-content details:has(> summary h2)");
  foldable_details.forEach(details => {
    details.addEventListener("toggle", () => { 
      updateSidebarFromDetailsElement(details); 
    });
  });

  // Sync even if this script runs after the load event has fired.
  if (document.readyState === "complete") {
    foldable_details.forEach(updateSidebarFromDetailsElement);
  } else {
    // mdbook js loads toc elements on DOMContentLoaded so we have to use window 'load' here
    window.addEventListener("load", ()=> { foldable_details.forEach(updateSidebarFromDetailsElement) }, { once: true });
  }
})();
