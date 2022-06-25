function bitmaps = GenerateShapeBitmaps()
    % GENERATESHAPEBITMAPS - Generates bitmaps of predefined shapes for use
    % in drawing textures. Add to this file to include other shapes. Shapes
    % are defined by the pixel coordinates of their vertices, and are
    % normalized to the area of a circle with a radius of 50. All output
    % bitmaps are 256x256.

    r = 50;
    circleArea = pi * r^2;

    % Implement any new shapes here
    GenerateCircle();
    GenerateTriangle();
    GenerateSquare();
    GenerateCross();

    function GenerateCircle()
        x = r * cosd(0:359);
        y = r * sind(0:359);
        circle = bitmap256([x' y']);
        bitmaps.Circle = circle;
    end

    function GenerateTriangle()
        verts = nsidedpoly(3).Vertices;
        triangle = bitmap256(verts);
        bitmaps.Triangle = triangle;
    end

    function GenerateSquare()
        verts = nsidedpoly(4).Vertices;
        square = bitmap256(verts);
        bitmaps.Square = square;
    end

    function GenerateCross()
        verts = [1,3; 1,1; 3,1; 3,-1; 1,-1; 1,-3; -1,-3; -1,-1; -3,-1; -3,1; -1,1; -1,3];
        cross = bitmap256(verts);
        bitmaps.Cross = cross;
    end

    function out = bitmap256(vertices)
        % Generates a 256x256 bitmap of the polygon defined by vertices, an
        % nx2 matrix of pixel coordinates. Output shapes are normalized to
        % the area of a circle of radius 50, and vertically flipped to
        % align with screen coordinates.

        x = vertices(:,1);
        y = vertices(:,2);
        norm = sqrt(polyarea(x, y) / circleArea);
        x_corrected = x/norm + 128;
        y_corrected = -y/norm + 128;

        mask = poly2mask(x_corrected, y_corrected, 256, 256);
        lum = double(mask);
        alpha = mask * 255;
        out(:, :, 1) = lum;
        out(:, :, 2) = alpha;
    end
end
