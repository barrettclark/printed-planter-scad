module drainage_holes(count, diameter, placement_radius, floor_thickness) {
    if (count > 0) {
        for (i = [0 : count - 1]) {
            angle = i * 360 / count;
            translate([placement_radius * cos(angle), placement_radius * sin(angle), -1])
                cylinder(h = floor_thickness + 2, d = diameter, $fn = 32);
        }
    }
}
